// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Parquet shredding (Layer 1 of 2)
//
// Takes a schemaless `JsonElement` tree and produces a fixed columnar model
// plus an inferred schema. Knows nothing about the Parquet byte format.
//
// The model is split into two reusable steps so large tables can stream:
//   plan()        - one full scan that fixes the schema (types + nullability +
//                   column order). Cheap: it inspects values but copies none.
//   materialize() - builds the columns for a row range [start, end) using the
//                   already-fixed schema. Called once for the whole table, or
//                   once per row-group slice by the streaming writer.
//
// SCOPE (phase 1): flat columns. Nested values are stored as JSON text in a
// BYTE_ARRAY(JSON) column rather than exploded into Parquet GROUP/LIST columns.

// MARK: - Logical column type

/// Logical type of a shredded column; the encoder maps these to Parquet
/// physical types + annotations (.string -> UTF8, .json -> JSON, both BYTE_ARRAY).
public enum ParquetLogicalType: UInt8, Equatable {
    case boolean
    case int64
    case double
    case string
    case json
}

// MARK: - Schema

public struct ParquetField: Equatable {
    public let name: Hitch
    public let type: ParquetLogicalType
    /// `true` if any row is missing this key or has an explicit JSON null.
    public let nullable: Bool

    public init(name: Hitch, type: ParquetLogicalType, nullable: Bool) {
        self.name = name
        self.type = type
        self.nullable = nullable
    }
}

// MARK: - Columnar storage

/// Holds ONLY the present (non-null) values for a column, in row order.
public enum ParquetColumnStorage: Equatable {
    case boolean([Bool])
    case int64([Int64])
    case double([Double])
    case bytes([Hitch])   // backs both .string and .json columns
}

public struct ParquetColumn: Equatable {
    public let field: ParquetField
    /// Per-row definition levels (1 = present, 0 = null). Empty when REQUIRED.
    public let definitionLevels: [UInt8]
    /// Present (non-null) values only.
    public let storage: ParquetColumnStorage

    public init(field: ParquetField, definitionLevels: [UInt8], storage: ParquetColumnStorage) {
        self.field = field
        self.definitionLevels = definitionLevels
        self.storage = storage
    }
}

public struct ParquetTable: Equatable {
    public let rowCount: Int
    public let columns: [ParquetColumn]
    public var schema: [ParquetField] { columns.map { $0.field } }

    public init(rowCount: Int, columns: [ParquetColumn]) {
        self.rowCount = rowCount
        self.columns = columns
    }
}

// MARK: - Options

public struct ParquetShredOptions {
    /// Column name when the top level is not an array-of-objects.
    public var scalarColumnName: Hitch
    public init(scalarColumnName: Hitch = "value") {
        self.scalarColumnName = scalarColumnName
    }
}

// MARK: - Public entrypoints

public extension JsonElement {
    /// Shred this element into a fully-materialized columnar `ParquetTable`.
    func toParquetTable(options: ParquetShredOptions = ParquetShredOptions()) -> ParquetTable {
        return ParquetShredder.shred(self, options: options)
    }

    /// Shred and serialize to Parquet, streaming row groups into `sink`. Only
    /// one row group is materialized at a time, so peak memory is bounded by
    /// `writeOptions.rowsPerRowGroup` rather than the whole table.
    func writeParquet(to sink: ParquetSink,
                      shredOptions: ParquetShredOptions = ParquetShredOptions(),
                      writeOptions: ParquetWriteOptions = ParquetWriteOptions()) {
        let plan = ParquetShredder.plan(self, options: shredOptions)
        let writer = ParquetWriter(sink: sink, schema: plan.fields, options: writeOptions)
        let n = plan.rowCount
        var r = 0
        while r < n {
            let e = min(r + writeOptions.rowsPerRowGroup, n)
            writer.writeRowGroup(columns: ParquetShredder.materialize(plan, rowStart: r, rowEnd: e),
                                 rowCount: e - r)
            r = e
        }
        writer.finish()
    }

    /// Convenience: stream Parquet to a file. Returns bytes written.
    @discardableResult
    func writeParquet(toFile url: URL,
                      shredOptions: ParquetShredOptions = ParquetShredOptions(),
                      writeOptions: ParquetWriteOptions = ParquetWriteOptions()) throws -> Int {
        let sink = try ParquetFileSink(url: url)
        defer { sink.close() }
        writeParquet(to: sink, shredOptions: shredOptions, writeOptions: writeOptions)
        return sink.offset
    }

    /// Convenience: shred and serialize the whole table to Parquet bytes.
    func toParquet(shredOptions: ParquetShredOptions = ParquetShredOptions(),
                   writeOptions: ParquetWriteOptions = ParquetWriteOptions()) -> Data {
        let sink = ParquetDataSink()
        writeParquet(to: sink, shredOptions: shredOptions, writeOptions: writeOptions)
        return sink.data
    }
}

// MARK: - Schema plan

/// The fixed schema plus everything `materialize` needs to build any row slice.
struct SchemaPlan {
    enum Mode { case records, single }
    let mode: Mode
    let rows: [JsonElement]
    let fields: [ParquetField]
    let order: [HalfHitch]        // records mode: column key by index
    let index: [HalfHitch: Int]   // records mode: key -> column index
    var rowCount: Int { rows.count }
}

// MARK: - Shredder

public enum ParquetShredder {

    private enum Inferred: Equatable {
        case unknown, boolean, int64, double, string, json
    }

    public static func shred(_ element: JsonElement,
                             options: ParquetShredOptions = ParquetShredOptions()) -> ParquetTable {
        let plan = plan(element, options: options)
        return ParquetTable(rowCount: plan.rowCount,
                            columns: materialize(plan, rowStart: 0, rowEnd: plan.rowCount))
    }

    // MARK: Row extraction

    private static func rowsAndMode(for element: JsonElement) -> ([JsonElement], SchemaPlan.Mode) {
        switch element.type {
        case .array:
            let vs = element.valueArray
            if vs.isEmpty == false && vs.allSatisfy({ $0.type == .dictionary }) {
                return (vs, .records)
            }
            return (vs, .single)
        case .dictionary:
            return ([element], .records)
        default:
            return ([element], .single)
        }
    }

    // MARK: Type inference

    private static func inferred(of e: JsonElement) -> Inferred {
        switch e.type {
        case .null:               return .unknown
        case .boolean:            return .boolean
        case .int:                return .int64
        case .double:             return .double
        case .string, .regex:     return .string
        case .array, .dictionary: return .json
        }
    }

    private static func join(_ a: Inferred, _ b: Inferred) -> Inferred {
        if a == b { return a }
        switch (a, b) {
        case (.unknown, let x), (let x, .unknown): return x
        case (.int64, .double), (.double, .int64): return .double
        default:                                   return .json
        }
    }

    private static func finalize(_ t: Inferred) -> ParquetLogicalType {
        switch t {
        case .unknown: return .string
        case .boolean: return .boolean
        case .int64:   return .int64
        case .double:  return .double
        case .string:  return .string
        case .json:    return .json
        }
    }

    // MARK: Pass 1 - plan (fix schema)

    static func plan(_ element: JsonElement, options: ParquetShredOptions) -> SchemaPlan {
        let (rows, mode) = rowsAndMode(for: element)
        let total = rows.count

        switch mode {
        case .records:
            var order: [HalfHitch] = []
            var index: [HalfHitch: Int] = [:]
            var types: [Inferred] = []
            var nonNull: [Int] = []

            for row in rows {
                guard row.type == .dictionary else { continue }
                let keys = row.keyArray
                let vals = row.valueArray
                let n = min(keys.count, vals.count)
                var seen = Set<Int>()
                for i in 0..<n {
                    let key = keys[i]
                    let c: Int
                    if let existing = index[key] {
                        c = existing
                    } else {
                        c = order.count
                        index[key] = c
                        order.append(key)
                        types.append(.unknown)
                        nonNull.append(0)
                    }
                    if seen.contains(c) { continue }   // ignore duplicate keys in a row
                    seen.insert(c)
                    let v = vals[i]
                    if v.type != .null {
                        types[c] = join(types[c], inferred(of: v))
                        nonNull[c] += 1
                    }
                }
            }

            var fields: [ParquetField] = []
            fields.reserveCapacity(order.count)
            for c in 0..<order.count {
                fields.append(ParquetField(name: order[c].hitch(),
                                           type: finalize(types[c]),
                                           nullable: nonNull[c] != total))
            }
            return SchemaPlan(mode: .records, rows: rows, fields: fields, order: order, index: index)

        case .single:
            var t: Inferred = .unknown
            var nonNull = 0
            for v in rows where v.type != .null {
                t = join(t, inferred(of: v))
                nonNull += 1
            }
            let field = ParquetField(name: Hitch(hitch: options.scalarColumnName),
                                     type: finalize(t),
                                     nullable: nonNull != total)
            return SchemaPlan(mode: .single, rows: rows, fields: [field], order: [], index: [:])
        }
    }

    // MARK: Pass 2 - materialize a row range

    static func materialize(_ plan: SchemaPlan, rowStart: Int, rowEnd: Int) -> [ParquetColumn] {
        let fields = plan.fields
        let builders = fields.map { ColumnBuilder(type: $0.type) }
        let rows = plan.rows

        switch plan.mode {
        case .records:
            let index = plan.index
            var seenEpoch = [Int](repeating: 0, count: fields.count)
            var epoch = 0
            for r in rowStart..<rowEnd {
                let row = rows[r]
                epoch += 1
                if row.type == .dictionary {
                    let keys = row.keyArray
                    let vals = row.valueArray
                    let n = min(keys.count, vals.count)
                    for i in 0..<n {
                        guard let c = index[keys[i]] else { continue }
                        guard seenEpoch[c] != epoch else { continue }
                        seenEpoch[c] = epoch
                        builders[c].append(vals[i])
                    }
                }
                for c in 0..<fields.count where seenEpoch[c] != epoch {
                    builders[c].appendNull()
                }
            }
        case .single:
            for r in rowStart..<rowEnd { builders[0].append(rows[r]) }
        }

        return (0..<fields.count).map { builders[$0].finish(field: fields[$0]) }
    }
}

// MARK: - Column builder

private final class ColumnBuilder {
    let type: ParquetLogicalType

    private var bools: [Bool] = []
    private var ints: [Int64] = []
    private var doubles: [Double] = []
    private var bytes: [Hitch] = []
    private var defLevels: [UInt8] = []

    init(type: ParquetLogicalType) { self.type = type }

    func append(_ e: JsonElement) {
        if e.type == .null { appendNull(); return }
        defLevels.append(1)
        switch type {
        case .boolean: bools.append(e.valueBool)
        case .int64:   ints.append(Int64(e.valueInt))
        case .double:  doubles.append(e.type == .int ? Double(e.valueInt) : e.valueDouble)
        case .string:  bytes.append(e.valueString.hitch())
        case .json:    bytes.append(e.toHitch())
        }
    }

    func appendNull() { defLevels.append(0) }

    func finish(field: ParquetField) -> ParquetColumn {
        let storage: ParquetColumnStorage
        switch type {
        case .boolean:        storage = .boolean(bools)
        case .int64:          storage = .int64(ints)
        case .double:         storage = .double(doubles)
        case .string, .json:  storage = .bytes(bytes)
        }
        return ParquetColumn(field: field,
                             definitionLevels: field.nullable ? defLevels : [],
                             storage: storage)
    }
}

// MARK: - Debug description

extension ParquetTable: CustomStringConvertible {
    public var description: String {
        let out = Hitch(capacity: 128)
        out.append("ParquetTable(rows: \(rowCount))\n")
        for column in columns {
            let f = column.field
            let req = f.nullable ? "optional" : "required"
            let present: Int
            switch column.storage {
            case .boolean(let a): present = a.count
            case .int64(let a):   present = a.count
            case .double(let a):  present = a.count
            case .bytes(let a):   present = a.count
            }
            out.append("  - \(f.name.toString()): \(f.type) \(req)  present=\(present)\n")
        }
        return out.toString()
    }
}
