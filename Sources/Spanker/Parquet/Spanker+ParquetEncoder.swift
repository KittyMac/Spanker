// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Parquet encoding (Layer 2 of 2)
//
// Turns columns into Parquet bytes. Byte layout (Thrift-compact metadata,
// DATA_PAGE v1, PLAIN values, RLE definition levels, Snappy/uncompressed,
// multi-page column chunks, multi-row-group files) validated end-to-end
// against Apache Arrow (pyarrow) before this Swift port.
//
// This file provides the page/metadata primitives and the whole-table
// convenience path. Streaming across row groups lives in `ParquetWriter`.

/// Page compression codec.
public enum ParquetCompression {
    case uncompressed
    case snappy

    var codecId: Int {   // Parquet CompressionCodec enum value
        switch self {
        case .uncompressed: return 0
        case .snappy:       return 1
        }
    }
}

// MARK: - Metadata accumulated while writing

struct ChunkMeta {
    let offset: Int          // file offset of the first page header
    let uncompressedSize: Int
    let compressedSize: Int
    let numValues: Int       // rows in this column chunk (this row group)
    let physical: Int
    let name: Hitch
    let codec: Int
}

struct RowGroupMeta {
    let rows: Int
    let chunks: [ChunkMeta]
}

// MARK: - Whole-table convenience

public extension ParquetTable {
    /// Serialize this table to Parquet bytes, chunked per `options`.
    func exportParquet(options: ParquetWriteOptions = ParquetWriteOptions()) -> Data {
        let sink = ParquetDataSink()
        let writer = ParquetWriter(sink: sink, schema: schema, options: options)

        var presentCursor = [Int](repeating: 0, count: columns.count)
        var r = 0
        while r < rowCount {
            let e = min(r + options.rowsPerRowGroup, rowCount)
            var batch: [ParquetColumn] = []
            batch.reserveCapacity(columns.count)
            for i in 0..<columns.count {
                let (sub, advance) = ParquetEncoder.sliceColumn(columns[i], field: schema[i],
                                                                rowStart: r, rowEnd: e,
                                                                presentStart: presentCursor[i])
                presentCursor[i] = advance
                batch.append(sub)
            }
            writer.writeRowGroup(columns: batch, rowCount: e - r)
            r = e
        }
        writer.finish()
        return sink.data
    }

    /// Back-compatible overload selecting only the codec.
    func exportParquet(compression: ParquetCompression) -> Data {
        return exportParquet(options: ParquetWriteOptions(compression: compression))
    }
}

// MARK: - Encoder primitives

enum ParquetEncoder {

    static func physicalType(_ t: ParquetLogicalType) -> Int {
        switch t {
        case .boolean:        return 0   // BOOLEAN
        case .int64:          return 2   // INT64
        case .double:         return 5   // DOUBLE
        case .string, .json:  return 6   // BYTE_ARRAY
        }
    }

    static func convertedType(_ t: ParquetLogicalType) -> Int? {
        switch t {
        case .string: return 0    // UTF8
        case .json:   return 19   // JSON
        default:      return nil
        }
    }

    // MARK: Column slicing (whole-table path)

    /// Extract rows [rowStart, rowEnd) of a column into a self-contained
    /// sub-column (levels reindexed to 0, present values copied out).
    /// `presentStart` is the running present-value cursor across slices.
    static func sliceColumn(_ column: ParquetColumn, field: ParquetField,
                            rowStart: Int, rowEnd: Int, presentStart: Int) -> (ParquetColumn, Int) {
        if field.nullable {
            let defSlice = Array(column.definitionLevels[rowStart..<rowEnd])
            var present = 0
            for d in defSlice { present += Int(d) }
            let range = presentStart..<(presentStart + present)
            return (ParquetColumn(field: field, definitionLevels: defSlice,
                                  storage: subStorage(column.storage, range)),
                    presentStart + present)
        } else {
            let range = rowStart..<rowEnd
            return (ParquetColumn(field: field, definitionLevels: [],
                                  storage: subStorage(column.storage, range)),
                    presentStart + (rowEnd - rowStart))
        }
    }

    private static func subStorage(_ s: ParquetColumnStorage, _ r: Range<Int>) -> ParquetColumnStorage {
        switch s {
        case .boolean(let a): return .boolean(Array(a[r]))
        case .int64(let a):   return .int64(Array(a[r]))
        case .double(let a):  return .double(Array(a[r]))
        case .bytes(let a):   return .bytes(Array(a[r]))
        }
    }

    // MARK: Data page (v1)

    /// Build one DATA_PAGE for a row range. `definitionLevels` is the per-row
    /// slice (empty/ignored when the field is REQUIRED); `valueRange` selects
    /// the present values; `numRows` is the row count in this page.
    static func buildPage(field: ParquetField,
                          definitionLevels: ArraySlice<UInt8>,
                          storage: ParquetColumnStorage,
                          valueRange: Range<Int>,
                          numRows: Int,
                          compression: ParquetCompression) -> (bytes: [UInt8], uncompressedSize: Int, compressedSize: Int) {
        let pageData = ByteBuffer(reserving: 256)
        if field.nullable {
            appendDefLevels(definitionLevels, into: pageData)
        }
        appendPlain(storage, range: valueRange, into: pageData)

        let uncompressedBody = pageData.count
        let body: [UInt8]
        switch compression {
        case .uncompressed: body = pageData.bytes
        case .snappy:       body = Snappy.compress(pageData.bytes)
        }

        let page = ByteBuffer(reserving: body.count + 32)
        let tw = ThriftWriter(page)
        tw.structBegin()                                  // PageHeader
        tw.field(1, K_I32); tw.int(0)                     // type = DATA_PAGE
        tw.field(2, K_I32); tw.int(uncompressedBody)      // uncompressed_page_size
        tw.field(3, K_I32); tw.int(body.count)            // compressed_page_size
        tw.field(5, K_STRUCT); tw.structBegin()           // DataPageHeader
        tw.field(1, K_I32); tw.int(numRows)               // num_values (rows incl. nulls)
        tw.field(2, K_I32); tw.int(0)                     // encoding = PLAIN
        tw.field(3, K_I32); tw.int(3)                     // definition_level_encoding = RLE
        tw.field(4, K_I32); tw.int(3)                     // repetition_level_encoding = RLE
        tw.structEnd()
        tw.structEnd()

        let headerLen = page.count
        page.append(bytes: body)
        return (page.bytes, headerLen + uncompressedBody, headerLen + body.count)
    }

    static func appendPlain(_ storage: ParquetColumnStorage, range: Range<Int>, into buf: ByteBuffer) {
        switch storage {
        case .boolean(let a):
            var bit = 0
            var cur: UInt8 = 0
            for idx in range {
                if a[idx] { cur |= (UInt8(1) << bit) }
                bit += 1
                if bit == 8 { buf.byte(cur); cur = 0; bit = 0 }
            }
            if bit != 0 { buf.byte(cur) }
        case .int64(let a):
            for idx in range { buf.leU64(UInt64(bitPattern: a[idx])) }
        case .double(let a):
            for idx in range { buf.leU64(a[idx].bitPattern) }
        case .bytes(let a):
            for idx in range {
                buf.leU32(UInt32(a[idx].count))
                buf.append(hitchBytes: a[idx])
            }
        }
    }

    // RLE/bit-packing hybrid (pure RLE runs, bit width 1) with the 4-byte LE
    // length prefix required by DATA_PAGE v1.
    static func appendDefLevels(_ levels: ArraySlice<UInt8>, into buf: ByteBuffer) {
        let rle = ByteBuffer(reserving: levels.count)
        var i = levels.startIndex
        let end = levels.endIndex
        while i < end {
            var j = i
            while j < end && levels[j] == levels[i] { j += 1 }
            let run = j - i
            rle.varint(UInt64(run << 1))
            rle.byte(levels[i])
            i = j
        }
        buf.leU32(UInt32(rle.count))
        buf.append(rle)
    }

    // MARK: File metadata (Thrift compact)

    static func fileMetaData(schema: [ParquetField],
                             rowGroups: [RowGroupMeta],
                             totalRows: Int) -> [UInt8] {
        let meta = ByteBuffer(reserving: 512 + rowGroups.count * 128)
        let tw = ThriftWriter(meta)
        tw.structBegin()                                          // FileMetaData
        tw.field(1, K_I32); tw.int(1)                             // version
        tw.field(2, K_LIST); tw.listBegin(1 + schema.count, K_STRUCT)   // schema (flat)
        schemaElement(tw, name: Hitch(string: "schema"),
                      physical: nil, repetition: nil,
                      numChildren: schema.count, converted: nil)
        for f in schema {
            schemaElement(tw, name: f.name,
                          physical: physicalType(f.type),
                          repetition: f.nullable ? 1 : 0,        // OPTIONAL : REQUIRED
                          numChildren: nil,
                          converted: convertedType(f.type))
        }
        tw.field(3, K_I64); tw.int(totalRows)                     // num_rows
        tw.field(4, K_LIST); tw.listBegin(rowGroups.count, K_STRUCT)  // row_groups
        for rg in rowGroups {
            tw.structBegin()                                      // RowGroup
            tw.field(1, K_LIST); tw.listBegin(rg.chunks.count, K_STRUCT)
            for ch in rg.chunks { columnChunk(tw, ch) }
            let total = rg.chunks.reduce(0) { $0 + $1.uncompressedSize }
            tw.field(2, K_I64); tw.int(total)                     // total_byte_size (uncompressed)
            tw.field(3, K_I64); tw.int(rg.rows)                   // num_rows
            tw.structEnd()
        }
        tw.field(6, K_BINARY); tw.binary(Hitch(string: "Spanker"))  // created_by
        tw.structEnd()
        return meta.bytes
    }

    static func schemaElement(_ tw: ThriftWriter, name: Hitch,
                              physical: Int?, repetition: Int?,
                              numChildren: Int?, converted: Int?) {
        tw.structBegin()
        if let p = physical    { tw.field(1, K_I32); tw.int(p) }
        if let r = repetition  { tw.field(3, K_I32); tw.int(r) }
        tw.field(4, K_BINARY); tw.binary(name)
        if let n = numChildren { tw.field(5, K_I32); tw.int(n) }
        if let c = converted   { tw.field(6, K_I32); tw.int(c) }
        tw.structEnd()
    }

    static func columnChunk(_ tw: ThriftWriter, _ ch: ChunkMeta) {
        tw.structBegin()                                          // ColumnChunk
        tw.field(2, K_I64); tw.int(ch.offset)                     // file_offset
        tw.field(3, K_STRUCT); tw.structBegin()                   // ColumnMetaData
        tw.field(1, K_I32); tw.int(ch.physical)                   // type
        tw.field(2, K_LIST); tw.listBegin(2, K_I32); tw.int(3); tw.int(0)  // encodings = [RLE, PLAIN]
        tw.field(3, K_LIST); tw.listBegin(1, K_BINARY); tw.binary(ch.name) // path_in_schema
        tw.field(4, K_I32); tw.int(ch.codec)                      // codec
        tw.field(5, K_I64); tw.int(ch.numValues)                  // num_values
        tw.field(6, K_I64); tw.int(ch.uncompressedSize)           // total_uncompressed_size
        tw.field(7, K_I64); tw.int(ch.compressedSize)             // total_compressed_size
        tw.field(9, K_I64); tw.int(ch.offset)                     // data_page_offset
        tw.structEnd()
        tw.structEnd()
    }
}

// MARK: - Byte buffer

final class ByteBuffer {
    private(set) var bytes: [UInt8]

    init(reserving: Int = 0) {
        bytes = []
        bytes.reserveCapacity(reserving)
    }

    var count: Int { bytes.count }
    func byte(_ b: UInt8) { bytes.append(b) }
    func append(_ other: ByteBuffer) { bytes.append(contentsOf: other.bytes) }
    func append(bytes raw: [UInt8]) { bytes.append(contentsOf: raw) }
    func append(hitchBytes h: Hitch) { bytes.append(contentsOf: h.dataCopy()) }

    func varint(_ value: UInt64) {
        var v = value
        while true {
            let b = UInt8(v & 0x7F)
            v >>= 7
            if v != 0 { bytes.append(b | 0x80) } else { bytes.append(b); return }
        }
    }

    func leU32(_ v: UInt32) {
        bytes.append(UInt8(v & 0xFF))
        bytes.append(UInt8((v >> 8) & 0xFF))
        bytes.append(UInt8((v >> 16) & 0xFF))
        bytes.append(UInt8((v >> 24) & 0xFF))
    }

    func leU64(_ v: UInt64) {
        var x = v
        for _ in 0..<8 { bytes.append(UInt8(x & 0xFF)); x >>= 8 }
    }
}

// MARK: - Thrift compact protocol writer

private let K_STOP: UInt8   = 0x00
private let K_I32: UInt8    = 5
private let K_I64: UInt8    = 6
private let K_BINARY: UInt8 = 8
private let K_LIST: UInt8   = 9
private let K_STRUCT: UInt8 = 12

final class ThriftWriter {
    private let b: ByteBuffer
    private var stack: [Int] = []
    private var last = 0

    init(_ b: ByteBuffer) { self.b = b }

    func structBegin() { stack.append(last); last = 0 }
    func structEnd() { b.byte(K_STOP); last = stack.removeLast() }

    func field(_ id: Int, _ ktype: UInt8) {
        let delta = id - last
        if delta > 0 && delta <= 15 {
            b.byte(UInt8(delta << 4) | ktype)
        } else {
            b.byte(ktype & 0x0F)
            b.varint(zigzag(Int64(id)))
        }
        last = id
    }

    func listBegin(_ size: Int, _ etype: UInt8) {
        if size <= 14 {
            b.byte(UInt8(size << 4) | etype)
        } else {
            b.byte(0xF0 | etype)
            b.varint(UInt64(size))
        }
    }

    func int(_ v: Int) { b.varint(zigzag(Int64(v))) }

    func binary(_ h: Hitch) {
        b.varint(UInt64(h.count))
        b.append(hitchBytes: h)
    }

    private func zigzag(_ n: Int64) -> UInt64 { UInt64(bitPattern: (n &<< 1) ^ (n >> 63)) }
}

// MARK: - Snappy (raw block format)

private enum Snappy {

    static func compress(_ input: [UInt8]) -> [UInt8] {
        var out = [UInt8]()
        out.reserveCapacity(input.count / 2 + 16)
        appendVarint(UInt64(input.count), &out)
        let n = input.count
        if n == 0 { return out }

        var table = [UInt32: Int](minimumCapacity: min(n, 1 << 16))
        var i = 0
        var nextEmit = 0
        while i + 4 <= n {
            let key = load32(input, i)
            let cand = table[key] ?? -1
            table[key] = i
            if cand >= 0 && cand < i
                && input[cand] == input[i] && input[cand + 1] == input[i + 1]
                && input[cand + 2] == input[i + 2] && input[cand + 3] == input[i + 3] {
                if nextEmit < i { emitLiteral(input, nextEmit, i - nextEmit, &out) }
                var mlen = 4
                while i + mlen < n && input[cand + mlen] == input[i + mlen] { mlen += 1 }
                emitCopy(offset: i - cand, length: mlen, &out)
                i += mlen
                nextEmit = i
            } else {
                i += 1
            }
        }
        if nextEmit < n { emitLiteral(input, nextEmit, n - nextEmit, &out) }
        return out
    }

    private static func load32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }

    private static func appendVarint(_ v: UInt64, _ out: inout [UInt8]) {
        var x = v
        while true {
            let b = UInt8(x & 0x7F)
            x >>= 7
            if x != 0 { out.append(b | 0x80) } else { out.append(b); return }
        }
    }

    private static func emitLiteral(_ b: [UInt8], _ start: Int, _ length: Int, _ out: inout [UInt8]) {
        let ln = length - 1
        if ln < 60 {
            out.append(UInt8(ln << 2))
        } else {
            var need = 0
            var t = ln
            while t > 0 { need += 1; t >>= 8 }
            if need < 1 { need = 1 }
            out.append(UInt8((59 + need) << 2))
            for k in 0..<need { out.append(UInt8((ln >> (8 * k)) & 0xFF)) }
        }
        out.append(contentsOf: b[start..<(start + length)])
    }

    private static func emitCopy(offset: Int, length: Int, _ out: inout [UInt8]) {
        var len = length
        while len > 0 {
            let chunk = len >= 64 ? 64 : len
            emitCopyChunk(offset: offset, length: chunk, &out)
            len -= chunk
        }
    }

    private static func emitCopyChunk(offset: Int, length: Int, _ out: inout [UInt8]) {
        if length >= 4 && length <= 11 && offset < 2048 {
            let tag = 0x01 | (((length - 4) & 0x7) << 2) | ((offset >> 8) << 5)
            out.append(UInt8(tag & 0xFF))
            out.append(UInt8(offset & 0xFF))
        } else if offset < 65536 {
            out.append(UInt8(0x02 | (((length - 1) & 0x3F) << 2)))
            out.append(UInt8(offset & 0xFF))
            out.append(UInt8((offset >> 8) & 0xFF))
        } else {
            out.append(UInt8(0x03 | (((length - 1) & 0x3F) << 2)))
            out.append(UInt8(offset & 0xFF))
            out.append(UInt8((offset >> 8) & 0xFF))
            out.append(UInt8((offset >> 16) & 0xFF))
            out.append(UInt8((offset >> 24) & 0xFF))
        }
    }
}
