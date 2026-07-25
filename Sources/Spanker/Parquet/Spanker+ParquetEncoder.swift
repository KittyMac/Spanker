// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Parquet encoding (Layer 2 of 2)
//
// Consumes a `ParquetTable` (produced by the shredder) and emits a valid
// Parquet file as `Data`. This layer knows nothing about JSON; it only sees
// columns, logical types, definition levels, and present values.
//
// SCOPE (phase 1): a single row group, one DATA_PAGE (v1) per column, PLAIN
// value encoding, RLE-encoded definition levels, and NO compression
// (UNCOMPRESSED codec). This is the smallest thing every Parquet reader
// accepts. Compression (Snappy/Zstd), dictionary encoding, multiple row
// groups, and column statistics are later, purely additive phases — none of
// them change this public surface.
//
// The exact byte layout here was validated by a reference implementation
// round-tripped through Apache Arrow (pyarrow) across every column type and
// nullability case before this Swift port was written.

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

public extension ParquetTable {
    /// Serialize this table to Parquet file bytes.
    ///
    /// - Parameter compression: page codec. Defaults to `.snappy`, the de-facto
    ///   Parquet default; pass `.uncompressed` to disable.
    func exportParquet(compression: ParquetCompression = .snappy) -> Data {
        let out = ByteBuffer(reserving: 1024)
        out.magic()                                   // "PAR1" header

        var chunks: [ChunkInfo] = []
        for column in columns {
            let offset = out.count
            let page = ParquetEncoder.buildDataPage(column: column,
                                                    rowCount: rowCount,
                                                    compression: compression)
            out.append(page.bytes)
            chunks.append(ChunkInfo(offset: offset,
                                    uncompressedSize: page.uncompressedSize,
                                    compressedSize: page.compressedSize,
                                    physical: ParquetEncoder.physicalType(column.field.type),
                                    name: column.field.name,
                                    codec: compression.codecId))
        }

        let meta = ByteBuffer(reserving: 512)
        ParquetEncoder.writeFileMetaData(into: meta, table: self, chunks: chunks)
        let metaLen = meta.count
        out.append(meta)
        out.leU32(UInt32(metaLen))                    // footer length (LE)
        out.magic()                                   // "PAR1" footer

        return Data(out.bytes)
    }
}

public extension JsonElement {
    /// Shred and serialize this element to Parquet file bytes in one step.
    func toParquet(options: ParquetShredOptions = ParquetShredOptions(),
                   compression: ParquetCompression = .snappy) -> Data {
        return toParquetTable(options: options).exportParquet(compression: compression)
    }
}

// MARK: - Encoder internals

private struct ChunkInfo {
    let offset: Int
    let uncompressedSize: Int   // page header + uncompressed body
    let compressedSize: Int     // page header + compressed body (bytes on disk)
    let physical: Int
    let name: Hitch
    let codec: Int
}

// A built column chunk: the bytes actually written, plus the size accounting
// the metadata needs (both include the uncompressed PageHeader).
private struct BuiltPage {
    let bytes: ByteBuffer
    let uncompressedSize: Int
    let compressedSize: Int
}

// Thrift compact protocol type nibbles.
private let K_STOP: UInt8   = 0x00
private let K_I32: UInt8    = 5
private let K_I64: UInt8    = 6
private let K_BINARY: UInt8 = 8
private let K_LIST: UInt8   = 9
private let K_STRUCT: UInt8 = 12

// Parquet enum values used below (inlined with comments where referenced):
//   PageType.DATA_PAGE = 0
//   Encoding.PLAIN = 0, Encoding.RLE = 3
//   CompressionCodec.UNCOMPRESSED = 0
//   FieldRepetitionType.REQUIRED = 0, OPTIONAL = 1
//   ConvertedType.UTF8 = 0, JSON = 19
//   Type: BOOLEAN=0, INT64=2, DOUBLE=5, BYTE_ARRAY=6

private enum ParquetEncoder {

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

    // MARK: Data page (v1)

    static func buildDataPage(column: ParquetColumn,
                              rowCount: Int,
                              compression: ParquetCompression) -> BuiltPage {
        // Uncompressed page body: definition levels (if nullable) followed by
        // PLAIN values. In a DATA_PAGE v1 the whole body is compressed as one
        // block; the PageHeader itself is never compressed.
        let pageData = ByteBuffer(reserving: 256)
        if column.field.nullable {
            appendDefLevels(column.definitionLevels, into: pageData)
        }
        appendPlain(column.storage, into: pageData)

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
        tw.field(1, K_I32); tw.int(rowCount)              // num_values (rows, incl. nulls)
        tw.field(2, K_I32); tw.int(0)                     // encoding = PLAIN
        tw.field(3, K_I32); tw.int(3)                     // definition_level_encoding = RLE
        tw.field(4, K_I32); tw.int(3)                     // repetition_level_encoding = RLE
        tw.structEnd()
        tw.structEnd()

        let headerLen = page.count
        page.append(bytes: body)

        return BuiltPage(bytes: page,
                         uncompressedSize: headerLen + uncompressedBody,
                         compressedSize: headerLen + body.count)
    }

    // PLAIN encoding of the present (non-null) values.
    static func appendPlain(_ storage: ParquetColumnStorage, into buf: ByteBuffer) {
        switch storage {
        case .boolean(let arr):
            // Bit-packed, LSB first.
            var bit = 0
            var cur: UInt8 = 0
            for v in arr {
                if v { cur |= (UInt8(1) << bit) }
                bit += 1
                if bit == 8 { buf.byte(cur); cur = 0; bit = 0 }
            }
            if bit != 0 { buf.byte(cur) }
        case .int64(let arr):
            for v in arr { buf.leU64(UInt64(bitPattern: v)) }
        case .double(let arr):
            for v in arr { buf.leU64(v.bitPattern) }
        case .bytes(let arr):
            for h in arr {
                buf.leU32(UInt32(h.count))   // BYTE_ARRAY length prefix (LE)
                buf.append(hitchBytes: h)
            }
        }
    }

    // Definition levels: RLE/bit-packing hybrid (pure RLE runs, bit width 1),
    // prefixed by a 4-byte little-endian length as required by DATA_PAGE v1.
    static func appendDefLevels(_ levels: [UInt8], into buf: ByteBuffer) {
        let rle = ByteBuffer(reserving: levels.count)
        var i = 0
        let n = levels.count
        while i < n {
            var j = i
            while j < n && levels[j] == levels[i] { j += 1 }
            let run = j - i
            rle.varint(UInt64(run << 1))   // RLE run header: (run << 1) | 0
            rle.byte(levels[i])            // width 1 => value stored in a single byte
            i = j
        }
        buf.leU32(UInt32(rle.count))
        buf.append(rle)
    }

    // MARK: File metadata (Thrift compact)

    static func writeFileMetaData(into meta: ByteBuffer, table: ParquetTable, chunks: [ChunkInfo]) {
        let tw = ThriftWriter(meta)
        tw.structBegin()                                          // FileMetaData
        tw.field(1, K_I32); tw.int(1)                             // version
        tw.field(2, K_LIST); tw.listBegin(1 + table.columns.count, K_STRUCT)  // schema (flat list)
        schemaElement(tw, name: Hitch(string: "schema"),
                      physical: nil, repetition: nil,
                      numChildren: table.columns.count, converted: nil)
        for column in table.columns {
            schemaElement(tw, name: column.field.name,
                          physical: physicalType(column.field.type),
                          repetition: column.field.nullable ? 1 : 0,   // OPTIONAL : REQUIRED
                          numChildren: nil,
                          converted: convertedType(column.field.type))
        }
        tw.field(3, K_I64); tw.int(table.rowCount)                // num_rows
        tw.field(4, K_LIST); tw.listBegin(1, K_STRUCT)            // row_groups
        tw.structBegin()                                          // RowGroup
        tw.field(1, K_LIST); tw.listBegin(chunks.count, K_STRUCT) // columns
        for ch in chunks { columnChunk(tw, ch, rowCount: table.rowCount) }
        let totalSize = chunks.reduce(0) { $0 + $1.uncompressedSize }
        tw.field(2, K_I64); tw.int(totalSize)                     // total_byte_size (uncompressed)
        tw.field(3, K_I64); tw.int(table.rowCount)                // num_rows
        tw.structEnd()
        tw.field(6, K_BINARY); tw.binary(Hitch(string: "Spanker"))  // created_by
        tw.structEnd()
    }

    static func schemaElement(_ tw: ThriftWriter,
                              name: Hitch,
                              physical: Int?,
                              repetition: Int?,
                              numChildren: Int?,
                              converted: Int?) {
        tw.structBegin()                                          // SchemaElement
        if let p = physical    { tw.field(1, K_I32); tw.int(p) }  // type
        if let r = repetition  { tw.field(3, K_I32); tw.int(r) }  // repetition_type
        tw.field(4, K_BINARY); tw.binary(name)                    // name (required)
        if let n = numChildren { tw.field(5, K_I32); tw.int(n) }  // num_children
        if let c = converted   { tw.field(6, K_I32); tw.int(c) }  // converted_type
        tw.structEnd()
    }

    static func columnChunk(_ tw: ThriftWriter, _ ch: ChunkInfo, rowCount: Int) {
        tw.structBegin()                                          // ColumnChunk
        tw.field(2, K_I64); tw.int(ch.offset)                     // file_offset
        tw.field(3, K_STRUCT); tw.structBegin()                   // ColumnMetaData
        tw.field(1, K_I32); tw.int(ch.physical)                   // type
        tw.field(2, K_LIST); tw.listBegin(2, K_I32); tw.int(3); tw.int(0)  // encodings = [RLE, PLAIN]
        tw.field(3, K_LIST); tw.listBegin(1, K_BINARY); tw.binary(ch.name) // path_in_schema
        tw.field(4, K_I32); tw.int(ch.codec)                      // codec
        tw.field(5, K_I64); tw.int(rowCount)                      // num_values
        tw.field(6, K_I64); tw.int(ch.uncompressedSize)           // total_uncompressed_size
        tw.field(7, K_I64); tw.int(ch.compressedSize)             // total_compressed_size
        tw.field(9, K_I64); tw.int(ch.offset)                     // data_page_offset
        tw.structEnd()
        tw.structEnd()
    }
}

// MARK: - Byte buffer

private final class ByteBuffer {
    var bytes: [UInt8]

    init(reserving: Int = 0) {
        bytes = []
        bytes.reserveCapacity(reserving)
    }

    var count: Int { bytes.count }

    func byte(_ b: UInt8) { bytes.append(b) }

    func append(_ other: ByteBuffer) { bytes.append(contentsOf: other.bytes) }

    func append(bytes raw: [UInt8]) { bytes.append(contentsOf: raw) }

    func append(hitchBytes h: Hitch) { bytes.append(contentsOf: h.dataCopy()) }

    func magic() { bytes.append(contentsOf: [0x50, 0x41, 0x52, 0x31]) }  // "PAR1"

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

private final class ThriftWriter {
    private let b: ByteBuffer
    private var stack: [Int] = []
    private var last = 0

    init(_ b: ByteBuffer) { self.b = b }

    func structBegin() {
        stack.append(last)
        last = 0
    }

    func structEnd() {
        b.byte(K_STOP)
        last = stack.removeLast()
    }

    func field(_ id: Int, _ ktype: UInt8) {
        let delta = id - last
        if delta > 0 && delta <= 15 {
            b.byte(UInt8(delta << 4) | ktype)
        } else {
            b.byte(ktype & 0x0F)
            b.varint(zigzag(Int64(id)))   // field id as zigzag varint
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

    /// Writes an i32/i64 value (Thrift encodes both as zigzag varint; identical
    /// for the non-negative values used throughout Parquet metadata).
    func int(_ v: Int) { b.varint(zigzag(Int64(v))) }

    func binary(_ h: Hitch) {
        b.varint(UInt64(h.count))
        b.append(hitchBytes: h)
    }

    private func zigzag(_ n: Int64) -> UInt64 {
        return UInt64(bitPattern: (n &<< 1) ^ (n >> 63))
    }
}

// MARK: - Snappy (raw block format)

// Snappy block compressor as used by Parquet: a varint uncompressed-length
// preamble followed by literal/copy elements (no stream framing or CRC).
// Greedy LZ77 keyed on exact 4-byte matches; emits valid, decent output rather
// than maximally optimal. Validated by decompression through Apache Arrow.
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
                if nextEmit < i {
                    emitLiteral(input, nextEmit, i - nextEmit, &out)
                }
                var mlen = 4
                while i + mlen < n && input[cand + mlen] == input[i + mlen] { mlen += 1 }
                emitCopy(offset: i - cand, length: mlen, &out)
                i += mlen
                nextEmit = i
            } else {
                i += 1
            }
        }
        if nextEmit < n {
            emitLiteral(input, nextEmit, n - nextEmit, &out)
        }
        return out
    }

    private static func load32(_ b: [UInt8], _ i: Int) -> UInt32 {
        return UInt32(b[i]) | (UInt32(b[i + 1]) << 8)
             | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
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
            out.append(UInt8(ln << 2))                 // tag: (ln << 2) | 00
        } else {
            var need = 0
            var t = ln
            while t > 0 { need += 1; t >>= 8 }
            if need < 1 { need = 1 }
            out.append(UInt8((59 + need) << 2))        // 60..63 in the length slot
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
            // 1-byte-offset copy: 01 | ((len-4)<<2) | ((offset>>8)<<5), then low 8 bits.
            let tag = 0x01 | (((length - 4) & 0x7) << 2) | ((offset >> 8) << 5)
            out.append(UInt8(tag & 0xFF))
            out.append(UInt8(offset & 0xFF))
        } else if offset < 65536 {
            // 2-byte-offset copy: 10 | ((len-1)<<2), then 2-byte LE offset.
            out.append(UInt8(0x02 | (((length - 1) & 0x3F) << 2)))
            out.append(UInt8(offset & 0xFF))
            out.append(UInt8((offset >> 8) & 0xFF))
        } else {
            // 4-byte-offset copy: 11 | ((len-1)<<2), then 4-byte LE offset.
            out.append(UInt8(0x03 | (((length - 1) & 0x3F) << 2)))
            out.append(UInt8(offset & 0xFF))
            out.append(UInt8((offset >> 8) & 0xFF))
            out.append(UInt8((offset >> 16) & 0xFF))
            out.append(UInt8((offset >> 24) & 0xFF))
        }
    }
}
