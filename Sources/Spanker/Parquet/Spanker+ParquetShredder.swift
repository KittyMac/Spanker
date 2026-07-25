// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Parquet shredding (Layer 1 of 2)
//
// This file is the "shredder": it takes a schemaless `JsonElement` tree and
// produces a fixed columnar representation plus an inferred schema. It knows
// NOTHING about the Parquet byte format (Thrift, pages, encodings, compression).
// That is the job of the downstream encoder, which consumes a `ParquetTable`.
//
// Keeping the two layers separate means the shredder is fully unit-testable on
// its own, and the encoder can later be swapped (e.g. for a native backend)
// without touching any of the semantic decisions made here.
//
// SCOPE (phase 1 / "Tier 1"): flat columns only. Nested dictionaries/arrays are
// stored as JSON text in a BYTE_ARRAY(JSON) column rather than being exploded
// into Parquet GROUP/LIST columns via the Dremel model. Full nested support is a
// later phase and can be layered on without changing this public surface.

// MARK: - Logical column type

/// The logical type of a shredded column. The encoder maps these to Parquet
/// physical types + logical/converted-type annotations:
///   .boolean -> BOOLEAN
///   .int64   -> INT64
///   .double  -> DOUBLE
///   .string  -> BYTE_ARRAY (UTF8)
///   .json    -> BYTE_ARRAY (JSON)   // nested values, or an irreconcilable mix
public enum ParquetLogicalType: UInt8, Equatable {
    case boolean
    case int64
    case double
    case string
    case json
}

// MARK: - Schema

/// One column in the inferred schema.
public struct ParquetField: Equatable {
    public let name: Hitch
    public let type: ParquetLogicalType
    /// `true` if any row is missing this key or has an explicit JSON null for it.
    /// The encoder emits OPTIONAL (with definition levels) when nullable, else REQUIRED.
    public let nullable: Bool

    public init(name: Hitch, type: ParquetLogicalType, nullable: Bool) {
        self.name = name
        self.type = type
        self.nullable = nullable
    }
}

// MARK: - Columnar storage

/// Holds ONLY the present (non-null) values for a column, in row order. This
/// mirrors Parquet's on-disk layout: a data page stores definition levels plus
/// the compacted list of non-null values.
public enum ParquetColumnStorage: Equatable {
    case boolean([Bool])
    case int64([Int64])
    case double([Double])
    case bytes([Hitch])   // backing store for both .string and .json columns
}

/// A single materialized column.
public struct ParquetColumn: Equatable {
    public let field: ParquetField
    /// Per-row definition levels: 1 = value present, 0 = null.
    /// Empty when the column is REQUIRED (`field.nullable == false`); in that
    /// case every row is present, so the encoder can omit levels entirely.
    public let definitionLevels: [UInt8]
    /// Present (non-null) values only.
    public let storage: ParquetColumnStorage

    public init(field: ParquetField,
                definitionLevels: [UInt8],
                storage: ParquetColumnStorage) {
        self.field = field
        self.definitionLevels = definitionLevels
        self.storage = storage
    }
}

/// The complete columnar table handed to the encoder.
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
    /// Column name used when the top level is not an array-of-objects (i.e. a
    /// bare scalar, or an array whose elements are not all dictionaries).
    public var scalarColumnName: Hitch

    public init(scalarColumnName: Hitch = "value") {
        self.scalarColumnName = scalarColumnName
    }
}

// MARK: - Public entrypoint

public extension JsonElement {
    /// Shred this element into a columnar `ParquetTable`.
    ///
    /// Row/column mapping:
    ///   - array of objects        -> one row per object; columns = union of keys
    ///   - single object           -> one row; columns = its keys
    ///   - array of non-objects    -> one column (`options.scalarColumnName`), one row per element
    ///   - bare scalar             -> one row, one column (`options.scalarColumnName`)
    func toParquetTable(options: ParquetShredOptions = ParquetShredOptions()) -> ParquetTable {
        return ParquetShredder.shred(self, options: options)
    }
}

// MARK: - Shredder

public enum ParquetShredder {

    private enum Mode {
        case records      // each row is a dictionary; columns come from keys
        case singleColumn // each row is a scalar/array value; one synthetic column
    }

    /// Type-inference lattice. `join` computes the least upper bound; `.unknown`
    /// is the identity (a column that has only seen nulls stays `.unknown`).
    private enum Inferred: Equatable {
        case unknown
        case boolean
        case int64
        case double
        case string
        case json
    }

    public static func shred(_ element: JsonElement,
                             options: ParquetShredOptions = ParquetShredOptions()) -> ParquetTable {
        let (rows, mode) = rowsAndMode(for: element)
        switch mode {
        case .records:      return shredRecords(rows: rows, options: options)
        case .singleColumn: return shredSingleColumn(rows: rows, options: options)
        }
    }

    // MARK: Row/column extraction

    private static func rowsAndMode(for element: JsonElement) -> ([JsonElement], Mode) {
        switch element.type {
        case .array:
            let vs = element.valueArray
            if vs.isEmpty == false && vs.allSatisfy({ $0.type == .dictionary }) {
                return (vs, .records)
            }
            return (vs, .singleColumn)
        case .dictionary:
            return ([element], .records)
        default:
            return ([element], .singleColumn)
        }
    }

    // MARK: Type inference

    private static func inferred(of e: JsonElement) -> Inferred {
        switch e.type {
        case .null:                 return .unknown   // contributes only nullability
        case .boolean:              return .boolean
        case .int:                  return .int64
        case .double:               return .double
        case .string, .regex:       return .string
        case .array, .dictionary:   return .json
        }
    }

    private static func join(_ a: Inferred, _ b: Inferred) -> Inferred {
        if a == b { return a }
        switch (a, b) {
        case (.unknown, let x), (let x, .unknown):    return x
        case (.int64, .double), (.double, .int64):    return .double
        default:                                      return .json  // any other mix
        }
    }

    private static func finalize(_ t: Inferred) -> ParquetLogicalType {
        switch t {
        case .unknown: return .string   // all-null column: type is arbitrary but must be valid
        case .boolean: return .boolean
        case .int64:   return .int64
        case .double:  return .double
        case .string:  return .string
        case .json:    return .json
        }
    }

    // MARK: Records mode

    private static func shredRecords(rows: [JsonElement],
                                     options: ParquetShredOptions) -> ParquetTable {
        let rowCount = rows.count

        // Pass 1: discover columns (in first-appearance order) and infer types.
        var order: [HalfHitch] = []            // column name by index, first-appearance order
        var index: [HalfHitch: Int] = [:]      // name -> column index
        var types: [Inferred] = []

        for row in rows {
            guard row.type == .dictionary else { continue }
            let keys = row.keyArray
            let vals = row.valueArray
            let n = min(keys.count, vals.count)
            for i in 0..<n {
                let key = keys[i]
                let colIdx: Int
                if let existing = index[key] {
                    colIdx = existing
                } else {
                    colIdx = order.count
                    index[key] = colIdx
                    order.append(key)
                    types.append(.unknown)
                }
                types[colIdx] = join(types[colIdx], inferred(of: vals[i]))
            }
        }

        let columnCount = order.count

        // Pass 2: materialize. Scatter each row's keys into per-column builders,
        // then mark any column not touched by this row as null.
        let builders = order.indices.map { ColumnBuilder(type: finalize(types[$0])) }
        var seenEpoch = [Int](repeating: 0, count: columnCount)
        var epoch = 0

        for row in rows {
            epoch += 1
            if row.type == .dictionary {
                let keys = row.keyArray
                let vals = row.valueArray
                let n = min(keys.count, vals.count)
                for i in 0..<n {
                    guard let c = index[keys[i]] else { continue }
                    // First-occurrence-wins for duplicate keys in a single row, so
                    // that a malformed object can't misalign this column vs the rest.
                    guard seenEpoch[c] != epoch else { continue }
                    seenEpoch[c] = epoch
                    builders[c].append(vals[i])   // handles JSON-null -> appendNull internally
                }
            }
            for c in 0..<columnCount where seenEpoch[c] != epoch {
                builders[c].appendNull()
            }
        }

        let columns = order.indices.map { c in
            builders[c].finish(name: order[c].hitch(), rowCount: rowCount)
        }
        return ParquetTable(rowCount: rowCount, columns: columns)
    }

    // MARK: Single-column mode

    private static func shredSingleColumn(rows: [JsonElement],
                                          options: ParquetShredOptions) -> ParquetTable {
        let rowCount = rows.count

        var t: Inferred = .unknown
        for v in rows { t = join(t, inferred(of: v)) }

        let builder = ColumnBuilder(type: finalize(t))
        for v in rows { builder.append(v) }

        let column = builder.finish(name: Hitch(hitch: options.scalarColumnName), rowCount: rowCount)
        return ParquetTable(rowCount: rowCount, columns: [column])
    }
}

// MARK: - Column builder

/// Accumulates one column's present values + definition levels during pass 2.
/// A reference type so it can be mutated in place inside `map`/loops without
/// index juggling.
private final class ColumnBuilder {
    let type: ParquetLogicalType

    private var bools: [Bool] = []
    private var ints: [Int64] = []
    private var doubles: [Double] = []
    private var bytes: [Hitch] = []
    private var defLevels: [UInt8] = []
    private var nonNull = 0

    init(type: ParquetLogicalType) {
        self.type = type
    }

    /// Append a JSON value. A JSON `null` (or absence, via `appendNull`) is
    /// treated as a SQL null regardless of the column's type.
    func append(_ e: JsonElement) {
        if e.type == .null {
            appendNull()
            return
        }
        defLevels.append(1)
        nonNull += 1
        switch type {
        case .boolean: bools.append(e.valueBool)
        case .int64:   ints.append(Int64(e.valueInt))
        case .double:  doubles.append(e.type == .int ? Double(e.valueInt) : e.valueDouble)
        case .string:  bytes.append(e.valueString.hitch())
        case .json:    bytes.append(e.toHitch())
        }
    }

    func appendNull() {
        defLevels.append(0)
    }

    func finish(name: Hitch, rowCount: Int) -> ParquetColumn {
        // A column is nullable iff not every row carried a present, non-null value.
        let nullable = nonNull != rowCount

        let storage: ParquetColumnStorage
        switch type {
        case .boolean:        storage = .boolean(bools)
        case .int64:          storage = .int64(ints)
        case .double:         storage = .double(doubles)
        case .string, .json:  storage = .bytes(bytes)
        }

        let field = ParquetField(name: name, type: type, nullable: nullable)
        return ParquetColumn(field: field,
                             definitionLevels: nullable ? defLevels : [],
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
