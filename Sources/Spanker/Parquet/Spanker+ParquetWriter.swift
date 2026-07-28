// NOTE: generated with Claude Opus 4.8

import Foundation

// MARK: - Streaming Parquet writer
//
// Writes a Parquet file one row group at a time into a `ParquetSink`, splitting
// each column chunk into size-bounded pages. Row-group metadata is accumulated
// and flushed as the footer on `finish()`. Peak memory is bounded by a single
// row group's worth of columns, so arbitrarily large tables can be written by
// feeding row groups sequentially (see `JsonElement.writeParquet`).

// MARK: - Sinks

/// A destination for Parquet bytes that tracks how many bytes have been written
/// (needed to compute absolute page offsets in the footer).
public protocol ParquetSink: AnyObject {
    func write(_ bytes: [UInt8])
    var offset: Int { get }
}

/// Accumulates the whole file in memory.
public final class ParquetDataSink: ParquetSink {
    public private(set) var bytes: [UInt8] = []
    public init() {}
    public func write(_ b: [UInt8]) { bytes.append(contentsOf: b) }
    public var offset: Int { bytes.count }
    public var data: Data { Data(bytes) }
}

/// Streams the file to disk; never holds the whole file in memory.
public final class ParquetFileSink: ParquetSink {
    private let handle: FileHandle
    public private(set) var offset: Int = 0

    public init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        self.handle = try FileHandle(forWritingTo: url)
    }

    public func write(_ b: [UInt8]) {
        handle.write(Data(b))
        offset += b.count
    }

    public func close() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            try? handle.close()
        } else {
            handle.closeFile()
        }
    }
}

// MARK: - Options

public struct ParquetWriteOptions {
    /// Rows per row group. Bounds the writer's working set and is the unit of
    /// reader parallelism.
    public var rowsPerRowGroup: Int
    /// Rows per data page within a column chunk. Bounds per-page read memory.
    public var rowsPerPage: Int
    public var compression: ParquetCompression

    public init(rowsPerRowGroup: Int = 100_000,
                rowsPerPage: Int = 20_000,
                compression: ParquetCompression = .snappy) {
        self.rowsPerRowGroup = max(1, rowsPerRowGroup)
        self.rowsPerPage = max(1, rowsPerPage)
        self.compression = compression
    }
}

// MARK: - Writer

public final class ParquetWriter {
    private let sink: ParquetSink
    private let schema: [ParquetField]
    private let options: ParquetWriteOptions
    private var rowGroups: [RowGroupMeta] = []
    private var totalRows = 0
    private var finished = false

    /// Creates a writer and emits the "PAR1" header. `schema` is fixed for the
    /// life of the file; every row group must supply columns matching it in
    /// order, type, and nullability.
    public init(sink: ParquetSink, schema: [ParquetField], options: ParquetWriteOptions = ParquetWriteOptions()) {
        self.sink = sink
        self.schema = schema
        self.options = options
        sink.write([0x50, 0x41, 0x52, 0x31])   // "PAR1"
    }

    /// Append one row group. `columns` are self-contained for this group:
    /// definition levels indexed 0..<rowCount, present values starting at 0.
    public func writeRowGroup(columns: [ParquetColumn], rowCount: Int) {
        precondition(!finished, "writeRowGroup called after finish()")
        precondition(columns.count == schema.count, "column count must match schema")
        guard rowCount > 0 else { return }

        var chunks: [ChunkMeta] = []
        chunks.reserveCapacity(columns.count)

        for i in 0..<columns.count {
            let column = columns[i]
            let field = schema[i]
            var firstOffset = -1
            var uTotal = 0
            var cTotal = 0
            var presentCursor = 0

            var p = 0
            while p < rowCount {
                let pe = min(p + options.rowsPerPage, rowCount)

                let present: Int
                if field.nullable {
                    var c = 0
                    for k in p..<pe { c += Int(column.definitionLevels[k]) }
                    present = c
                } else {
                    present = pe - p
                }

                let defSlice: ArraySlice<UInt8> = field.nullable
                    ? column.definitionLevels[p..<pe]
                    : ArraySlice<UInt8>()

                let page = ParquetEncoder.buildPage(field: field,
                                                    definitionLevels: defSlice,
                                                    storage: column.storage,
                                                    valueRange: presentCursor..<(presentCursor + present),
                                                    numRows: pe - p,
                                                    compression: options.compression)
                if firstOffset < 0 { firstOffset = sink.offset }
                sink.write(page.bytes)
                uTotal += page.uncompressedSize
                cTotal += page.compressedSize
                presentCursor += present
                p = pe
            }

            chunks.append(ChunkMeta(offset: firstOffset,
                                    uncompressedSize: uTotal,
                                    compressedSize: cTotal,
                                    numValues: rowCount,
                                    physical: ParquetEncoder.physicalType(field.type),
                                    name: field.name,
                                    codec: options.compression.codecId))
        }

        rowGroups.append(RowGroupMeta(rows: rowCount, chunks: chunks))
        totalRows += rowCount
    }

    /// Write the footer (schema + all row-group metadata) and closing magic.
    /// Idempotent; further `writeRowGroup` calls are not allowed after this.
    public func finish() {
        guard !finished else { return }
        finished = true

        let meta = ParquetEncoder.fileMetaData(schema: schema, rowGroups: rowGroups, totalRows: totalRows)
        sink.write(meta)

        let n = UInt32(meta.count)
        sink.write([UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF),
                    UInt8((n >> 16) & 0xFF), UInt8((n >> 24) & 0xFF)])
        sink.write([0x50, 0x41, 0x52, 0x31])   // "PAR1"
    }
}
