// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Native nested Parquet encoding
//
// Writes a nested Parquet file (GROUP nodes + the 3-level LIST expansion), one
// column chunk per leaf, each page carrying repetition levels then definition
// levels then PLAIN values. Supports multiple row groups so it can stream.
// Byte layout mirrors nested_ref.py, validated end-to-end against Apache Arrow
// (including multi-row-group and Snappy).

public extension JsonElement {
    /// Serialize to Parquet with a native nested schema inferred from the data:
    /// objects become structs, arrays become lists, scalars become typed
    /// columns. This is the default — use `toParquetFlat()` for the old
    /// JSON-string representation of nested values.
    func toParquet(compression: ParquetCompression = .snappy) -> Data {
        let records = (type == .array) ? valueArray : [self]
        let schema = ParquetNestedInference.schema(for: records)
        return toParquet(schema: schema, compression: compression)
    }

    /// Serialize with an explicit native-nested schema.
    func toParquet(schema: [ParquetSchemaNode], compression: ParquetCompression = .snappy) -> Data {
        let records = (type == .array) ? valueArray : [self]
        let table = ParquetNestedShredder.shred(schema: schema, records: records)
        return ParquetNestedEncoder.encode(schema: schema, table: table, compression: compression)
    }
}

// MARK: - Metadata accumulated per row group

struct NestedChunkMeta {
    let offset: Int
    let uncompressedSize: Int
    let compressedSize: Int
    let numValues: Int
    let path: [Hitch]
    let physical: Int
}

struct NestedRowGroupMeta {
    let rows: Int
    let chunks: [NestedChunkMeta]
}

// MARK: - Streaming nested writer

public final class ParquetNestedWriter {
    private let sink: ParquetSink
    private let schema: [ParquetSchemaNode]
    private let compression: ParquetCompression
    private var rowGroups: [NestedRowGroupMeta] = []
    private var totalRows = 0
    private var finished = false

    /// Creates a writer and emits the "PAR1" header. `schema` is fixed; every
    /// row group must supply leaf columns matching `leaves(of: schema)` order.
    public init(sink: ParquetSink, schema: [ParquetSchemaNode],
                compression: ParquetCompression = .snappy) {
        ParquetSchema.annotate(schema)
        self.sink = sink
        self.schema = schema
        self.compression = compression
        sink.write([0x50, 0x41, 0x52, 0x31])   // "PAR1"
    }

    /// Append one row group's worth of leaf columns.
    public func writeRowGroup(leaves: [ParquetLeafColumn], rowCount: Int) {
        precondition(!finished, "writeRowGroup called after finish()")
        guard rowCount > 0 else { return }

        var chunks: [NestedChunkMeta] = []
        chunks.reserveCapacity(leaves.count)
        for leaf in leaves {
            let offset = sink.offset
            let page = ParquetNestedEncoder.buildLeafPage(leaf, compression: compression)
            sink.write(page.bytes)
            chunks.append(NestedChunkMeta(offset: offset,
                                          uncompressedSize: page.uncompressedSize,
                                          compressedSize: page.compressedSize,
                                          numValues: leaf.definitionLevels.count,
                                          path: leaf.path,
                                          physical: ParquetEncoder.physicalType(leaf.type)))
        }
        rowGroups.append(NestedRowGroupMeta(rows: rowCount, chunks: chunks))
        totalRows += rowCount
    }

    /// Write the footer (nested schema + all row groups) and closing magic.
    public func finish() {
        guard !finished else { return }
        finished = true
        let meta = ParquetNestedEncoder.fileMetaData(schema: schema, rowGroups: rowGroups,
                                                     totalRows: totalRows, compression: compression)
        sink.write(meta)
        let n = UInt32(meta.count)
        sink.write([UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF),
                    UInt8((n >> 16) & 0xFF), UInt8((n >> 24) & 0xFF)])
        sink.write([0x50, 0x41, 0x52, 0x31])
    }
}

// MARK: - Codable-keyed nested streaming writer

public final class ParquetNestedStreamWriter {
    public let schema: [ParquetSchemaNode]
    private let accumulator: NestedRowAccumulator
    private let writer: ParquetNestedWriter
    private let rowsPerRowGroup: Int
    private var finished = false

    public init<T: Decodable>(sink: ParquetSink, rowType: T.Type,
                              maxRecursionDepth: Int = 3,
                              writeOptions: ParquetWriteOptions = ParquetWriteOptions()) {
        let s = ParquetCodableSchema.nestedColumns(for: T.self, maxRecursionDepth: maxRecursionDepth)
        self.schema = s
        self.accumulator = NestedRowAccumulator(schema: s)
        self.writer = ParquetNestedWriter(sink: sink, schema: s, compression: writeOptions.compression)
        self.rowsPerRowGroup = writeOptions.rowsPerRowGroup
    }

    /// Append one row (a JSON object matching the row type).
    public func append(_ row: JsonElement) {
        precondition(!finished, "append called after finish()")
        accumulator.append(row)
        if accumulator.rowCount >= rowsPerRowGroup { flush() }
    }

    /// Append every element of a JSON array of rows.
    public func append(contentsOf rows: JsonElement) {
        precondition(!finished, "append called after finish()")
        guard rows.type == .array else { return }
        for row in rows.valueArray {
            accumulator.append(row)
            if accumulator.rowCount >= rowsPerRowGroup { flush() }
        }
    }

    private func flush() {
        let group = accumulator.takeRowGroup()
        guard group.rowCount > 0 else { return }
        writer.writeRowGroup(leaves: group.leaves, rowCount: group.rowCount)
    }

    public func finish() {
        guard !finished else { return }
        finished = true
        flush()
        writer.finish()
    }
}

// MARK: - Encoder primitives

public enum ParquetNestedEncoder {

    /// Single-shot: serialize a fully-shredded nested table (one row group).
    public static func encode(schema: [ParquetSchemaNode], table: ParquetNestedTable,
                              compression: ParquetCompression = .snappy) -> Data {
        let sink = ParquetDataSink()
        let writer = ParquetNestedWriter(sink: sink, schema: schema, compression: compression)
        writer.writeRowGroup(leaves: table.leaves, rowCount: table.rowCount)
        writer.finish()
        return sink.data
    }

    // MARK: Data page (one per leaf per row group)

    static func buildLeafPage(_ leaf: ParquetLeafColumn,
                              compression: ParquetCompression) -> (bytes: [UInt8], uncompressedSize: Int, compressedSize: Int) {
        let body = ByteBuffer(reserving: 256)
        if leaf.maxRepetitionLevel > 0 {
            appendLevels(leaf.repetitionLevels, bitWidth: bitWidth(leaf.maxRepetitionLevel), into: body)
        }
        if leaf.maxDefinitionLevel > 0 {
            appendLevels(leaf.definitionLevels, bitWidth: bitWidth(leaf.maxDefinitionLevel), into: body)
        }
        ParquetEncoder.appendPlain(leaf.storage, range: 0..<storageCount(leaf.storage), into: body)

        let uncompressedBody = body.count
        let compressedBody: [UInt8]
        switch compression {
        case .uncompressed: compressedBody = body.bytes
        case .snappy:       compressedBody = Snappy.compress(body.bytes)
        }

        let page = ByteBuffer(reserving: compressedBody.count + 32)
        let tw = ThriftWriter(page)
        tw.structBegin()
        tw.field(1, K_I32); tw.int(0)                         // DATA_PAGE
        tw.field(2, K_I32); tw.int(uncompressedBody)
        tw.field(3, K_I32); tw.int(compressedBody.count)
        tw.field(5, K_STRUCT); tw.structBegin()
        tw.field(1, K_I32); tw.int(leaf.definitionLevels.count)  // num_values (entries)
        tw.field(2, K_I32); tw.int(0)                         // PLAIN
        tw.field(3, K_I32); tw.int(3)                         // def levels RLE
        tw.field(4, K_I32); tw.int(3)                         // rep levels RLE
        tw.structEnd()
        tw.structEnd()

        let headerLen = page.count
        page.append(bytes: compressedBody)
        return (page.bytes, headerLen + uncompressedBody, headerLen + compressedBody.count)
    }

    private static func appendLevels(_ levels: [UInt8], bitWidth: Int, into buf: ByteBuffer) {
        let rle = ByteBuffer(reserving: levels.count)
        let nbytes = max(1, (bitWidth + 7) / 8)
        var i = 0
        while i < levels.count {
            var j = i
            while j < levels.count && levels[j] == levels[i] { j += 1 }
            rle.varint(UInt64((j - i) << 1))
            var v = UInt64(levels[i])
            for _ in 0..<nbytes { rle.byte(UInt8(v & 0xFF)); v >>= 8 }
            i = j
        }
        buf.leU32(UInt32(rle.count))
        buf.append(rle)
    }

    private static func bitWidth(_ maxLevel: Int) -> Int {
        var bits = 0
        var v = maxLevel
        while v > 0 { bits += 1; v >>= 1 }
        return bits
    }

    private static func storageCount(_ s: ParquetColumnStorage) -> Int {
        switch s {
        case .boolean(let a): return a.count
        case .int64(let a):   return a.count
        case .double(let a):  return a.count
        case .bytes(let a):   return a.count
        }
    }

    // MARK: File metadata

    static func fileMetaData(schema: [ParquetSchemaNode], rowGroups: [NestedRowGroupMeta],
                             totalRows: Int, compression: ParquetCompression) -> [UInt8] {
        let meta = ByteBuffer(reserving: 512 + rowGroups.count * 128)
        let tw = ThriftWriter(meta)
        tw.structBegin()
        tw.field(1, K_I32); tw.int(1)                             // version

        let totalNodes = 1 + schema.reduce(0) { $0 + countSchemaNodes($1) }
        tw.field(2, K_LIST); tw.listBegin(totalNodes, K_STRUCT)
        writeSchemaElement(tw, type: nil, repetition: nil, name: Hitch(string: "schema"),
                           numChildren: schema.count, converted: nil)
        for node in schema { emitSchema(tw, node) }

        tw.field(3, K_I64); tw.int(totalRows)

        if rowGroups.isEmpty {
            tw.field(4, K_LIST); tw.listBegin(0, K_STRUCT)
        } else {
            tw.field(4, K_LIST); tw.listBegin(rowGroups.count, K_STRUCT)
            for rg in rowGroups {
                tw.structBegin()
                tw.field(1, K_LIST); tw.listBegin(rg.chunks.count, K_STRUCT)
                for ch in rg.chunks { writeColumnChunk(tw, ch, compression: compression) }
                let total = rg.chunks.reduce(0) { $0 + $1.uncompressedSize }
                tw.field(2, K_I64); tw.int(total)                // total_byte_size
                tw.field(3, K_I64); tw.int(rg.rows)              // num_rows
                tw.structEnd()
            }
        }

        tw.field(6, K_BINARY); tw.binary(Hitch(string: "Spanker"))
        tw.structEnd()
        return meta.bytes
    }

    private static func emitSchema(_ tw: ThriftWriter, _ node: ParquetSchemaNode) {
        switch node.kind {
        case .leaf:
            writeSchemaElement(tw, type: ParquetEncoder.physicalType(node.type),
                               repetition: Int(node.repetition.rawValue), name: node.name,
                               numChildren: nil, converted: ParquetEncoder.convertedType(node.type))
        case .group:
            writeSchemaElement(tw, type: nil, repetition: Int(node.repetition.rawValue),
                               name: node.name, numChildren: node.children.count, converted: nil)
            for c in node.children { emitSchema(tw, c) }
        case .list:
            writeSchemaElement(tw, type: nil, repetition: Int(node.repetition.rawValue),
                               name: node.name, numChildren: 1, converted: 3)   // LIST
            writeSchemaElement(tw, type: nil, repetition: 2, name: Hitch(string: "list"),
                               numChildren: 1, converted: nil)                   // REPEATED
            emitSchema(tw, node.element!)
        }
    }

    private static func writeSchemaElement(_ tw: ThriftWriter, type: Int?, repetition: Int?,
                                           name: Hitch, numChildren: Int?, converted: Int?) {
        tw.structBegin()
        if let t = type       { tw.field(1, K_I32); tw.int(t) }
        if let r = repetition  { tw.field(3, K_I32); tw.int(r) }
        tw.field(4, K_BINARY); tw.binary(name)
        if let n = numChildren { tw.field(5, K_I32); tw.int(n) }
        if let c = converted   { tw.field(6, K_I32); tw.int(c) }
        tw.structEnd()
    }

    private static func countSchemaNodes(_ node: ParquetSchemaNode) -> Int {
        switch node.kind {
        case .leaf:  return 1
        case .group: return 1 + node.children.reduce(0) { $0 + countSchemaNodes($1) }
        case .list:  return 2 + countSchemaNodes(node.element!)
        }
    }

    private static func writeColumnChunk(_ tw: ThriftWriter, _ ch: NestedChunkMeta,
                                         compression: ParquetCompression) {
        tw.structBegin()
        tw.field(2, K_I64); tw.int(ch.offset)                     // file_offset
        tw.field(3, K_STRUCT); tw.structBegin()                   // ColumnMetaData
        tw.field(1, K_I32); tw.int(ch.physical)
        tw.field(2, K_LIST); tw.listBegin(2, K_I32); tw.int(3); tw.int(0)   // encodings [RLE, PLAIN]
        tw.field(3, K_LIST); tw.listBegin(ch.path.count, K_BINARY)
        for p in ch.path { tw.binary(p) }
        tw.field(4, K_I32); tw.int(compression.codecId)
        tw.field(5, K_I64); tw.int(ch.numValues)
        tw.field(6, K_I64); tw.int(ch.uncompressedSize)
        tw.field(7, K_I64); tw.int(ch.compressedSize)
        tw.field(9, K_I64); tw.int(ch.offset)
        tw.structEnd()
        tw.structEnd()
    }
}
