// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Schema from a Codable type
//
// Swift exposes no field list for a *type* (Mirror reflects instances, not
// types). The standard way to recover structure from a type alone is to run
// its synthesized `init(from:)` against a fake Decoder that, instead of
// decoding real data, records which key was requested, with which type, and
// whether via `decode` (required) or `decodeIfPresent` (optional -> nullable).
// Property/declaration order falls out because synthesized decoding runs in
// order.
//
// Mapping (flat, phase-1): Bool -> boolean; all integer widths -> int64;
// Float/Double -> double; String -> string; everything else (arrays,
// dictionaries, nested structs, dates, ...) -> json.
//
// KNOWN LIMITATION: this drives real decoding with placeholder values, so a
// type whose `init(from:)` rejects placeholders - most commonly a
// RawRepresentable enum (e.g. `enum Role: String, Codable`) whose init fails on
// an empty raw value - will make the probe throw `.unsupportedField`. Represent
// such fields as their raw type, or derive the schema from a sample instance
// instead (see note in the accompanying tests).

public enum ParquetSchemaError: Error, CustomStringConvertible {
    /// A field could not be probed because its type's decoder rejected the
    /// placeholder value used during probing (e.g. a raw-value enum).
    case unsupportedField(key: String, type: String, underlying: Error)
    /// Probing recursed past the safety limit (pathological non-optional
    /// self-referential type). Such a type has no finite Parquet schema.
    case tooDeep(key: String)

    public var description: String {
        switch self {
        case .unsupportedField(let key, let type, let underlying):
            return "Cannot derive a Parquet column for '\(key)' of type \(type): its decoder "
                 + "rejected a placeholder value (\(underlying)). Represent it as its raw/primitive "
                 + "type, or build the schema from a sample instance."
        case .tooDeep(let key):
            return "Field '\(key)' is self-referential without an Optional/Array break; "
                 + "it has no finite Parquet schema."
        }
    }
}

public enum ParquetCodableSchema {
    /// Derive Parquet columns from a Decodable *row* type. For an
    /// array-of-objects table, pass the element (row) type, e.g. `Person.self`.
    public static func columns<T: Decodable>(for type: T.Type,
                                             scalarColumnName: Hitch = "value") throws -> [ParquetField] {
        let recorder = SchemaRecorder()
        let decoder = ProbeDecoder(recorder: recorder, depth: 0)
        do {
            _ = try T(from: decoder)
        } catch let e as ParquetSchemaError {
            throw e
        } catch {
            // A throw here means a field's decoder rejected a placeholder before
            // the outer type finished; surface the field we were on.
            throw ParquetSchemaError.unsupportedField(key: recorder.currentKey ?? "<root>",
                                                      type: "\(T.self)", underlying: error)
        }
        return recorder.fields(scalarColumnName: scalarColumnName)
    }
}

// MARK: - Recording

fileprivate func logicalType(for type: Any.Type) -> ParquetLogicalType {
    if type == Bool.self { return .boolean }
    if type == String.self { return .string }
    if type == Double.self || type == Float.self { return .double }
    if type == Int.self   || type == Int8.self  || type == Int16.self
        || type == Int32.self || type == Int64.self
        || type == UInt.self  || type == UInt8.self || type == UInt16.self
        || type == UInt32.self || type == UInt64.self { return .int64 }
    return .json   // arrays, dictionaries, nested structs, dates, enums, ...
}

fileprivate final class SchemaRecorder {
    private struct Entry { var type: ParquetLogicalType; var nullable: Bool }
    private var order: [String] = []
    private var byKey: [String: Entry] = [:]

    private var singleType: ParquetLogicalType?
    private var singleNullable = false

    /// The key currently being probed, for error reporting.
    var currentKey: String?

    func recordKeyed(_ key: String, _ type: ParquetLogicalType, nullable: Bool) {
        currentKey = key
        if byKey[key] == nil { order.append(key) }
        byKey[key] = Entry(type: type, nullable: nullable)
    }

    func recordSingle(_ type: ParquetLogicalType, nullable: Bool) {
        singleType = type
        singleNullable = nullable
    }

    func fields(scalarColumnName: Hitch) -> [ParquetField] {
        if order.isEmpty == false {
            return order.map { key in
                let e = byKey[key]!
                return ParquetField(name: Hitch(string: key), type: e.type, nullable: e.nullable)
            }
        }
        if let t = singleType {
            return [ParquetField(name: scalarColumnName, type: t, nullable: singleNullable)]
        }
        return []
    }
}

// MARK: - Probe decoder (records the top-level shape)

fileprivate final class ProbeDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let recorder: SchemaRecorder
    let depth: Int

    init(recorder: SchemaRecorder, depth: Int) {
        self.recorder = recorder
        self.depth = depth
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(ProbeKeyed<Key>(recorder: recorder, depth: depth))
    }
    func unkeyedContainer() -> UnkeyedDecodingContainer { EmptyUnkeyed() }
    func singleValueContainer() -> SingleValueDecodingContainer { ProbeSingle(recorder: recorder, depth: depth) }
}

// Records each keyed field. Overrides both `decode` (required) and
// `decodeIfPresent` (nullable) so optionals are detected - the stdlib default
// `decodeIfPresent` would otherwise route through `decode` and lose nullability.
fileprivate struct ProbeKeyed<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let recorder: SchemaRecorder
    let depth: Int
    var codingPath: [CodingKey] = []
    var allKeys: [Key] = []

    func contains(_ key: Key) -> Bool { true }
    func decodeNil(forKey key: Key) throws -> Bool { false }

    private func req(_ key: Key, _ t: ParquetLogicalType) { recorder.recordKeyed(key.stringValue, t, nullable: false) }
    private func opt(_ key: Key, _ t: ParquetLogicalType) { recorder.recordKeyed(key.stringValue, t, nullable: true) }

    func decode(_ type: Bool.Type,   forKey key: Key) throws -> Bool   { req(key, .boolean); return false }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { req(key, .string);  return "" }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { req(key, .double);  return 0 }
    func decode(_ type: Float.Type,  forKey key: Key) throws -> Float  { req(key, .double);  return 0 }
    func decode(_ type: Int.Type,    forKey key: Key) throws -> Int    { req(key, .int64);   return 0 }
    func decode(_ type: Int8.Type,   forKey key: Key) throws -> Int8   { req(key, .int64);   return 0 }
    func decode(_ type: Int16.Type,  forKey key: Key) throws -> Int16  { req(key, .int64);   return 0 }
    func decode(_ type: Int32.Type,  forKey key: Key) throws -> Int32  { req(key, .int64);   return 0 }
    func decode(_ type: Int64.Type,  forKey key: Key) throws -> Int64  { req(key, .int64);   return 0 }
    func decode(_ type: UInt.Type,   forKey key: Key) throws -> UInt   { req(key, .int64);   return 0 }
    func decode(_ type: UInt8.Type,  forKey key: Key) throws -> UInt8  { req(key, .int64);   return 0 }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { req(key, .int64);   return 0 }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { req(key, .int64);   return 0 }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { req(key, .int64);   return 0 }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        req(key, logicalType(for: T.self))
        return try makeDummy(T.self, key: key.stringValue, depth: depth + 1)
    }

    func decodeIfPresent(_ type: Bool.Type,   forKey key: Key) throws -> Bool?   { opt(key, .boolean); return nil }
    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? { opt(key, .string);  return nil }
    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? { opt(key, .double);  return nil }
    func decodeIfPresent(_ type: Float.Type,  forKey key: Key) throws -> Float?  { opt(key, .double);  return nil }
    func decodeIfPresent(_ type: Int.Type,    forKey key: Key) throws -> Int?    { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: Int8.Type,   forKey key: Key) throws -> Int8?   { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: Int16.Type,  forKey key: Key) throws -> Int16?  { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: Int32.Type,  forKey key: Key) throws -> Int32?  { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: Int64.Type,  forKey key: Key) throws -> Int64?  { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: UInt.Type,   forKey key: Key) throws -> UInt?   { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: UInt8.Type,  forKey key: Key) throws -> UInt8?  { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? { opt(key, .int64);   return nil }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? { opt(key, .int64);   return nil }
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        opt(key, logicalType(for: T.self))
        return nil
    }

    func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type, forKey key: Key) throws -> KeyedDecodingContainer<NK> {
        KeyedDecodingContainer(DummyKeyed<NK>(depth: depth + 1))
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { EmptyUnkeyed() }
    func superDecoder() throws -> Decoder { DummyDecoder(depth: depth + 1) }
    func superDecoder(forKey key: Key) throws -> Decoder { DummyDecoder(depth: depth + 1) }
}

// Top-level single value (e.g. `columns(for: Int.self)`), records one column.
fileprivate struct ProbeSingle: SingleValueDecodingContainer {
    let recorder: SchemaRecorder
    let depth: Int
    var codingPath: [CodingKey] = []

    func decodeNil() -> Bool { false }
    func decode(_ type: Bool.Type)   throws -> Bool   { recorder.recordSingle(.boolean, nullable: false); return false }
    func decode(_ type: String.Type) throws -> String { recorder.recordSingle(.string,  nullable: false); return "" }
    func decode(_ type: Double.Type) throws -> Double { recorder.recordSingle(.double,  nullable: false); return 0 }
    func decode(_ type: Float.Type)  throws -> Float  { recorder.recordSingle(.double,  nullable: false); return 0 }
    func decode(_ type: Int.Type)    throws -> Int    { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: Int8.Type)   throws -> Int8   { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: Int16.Type)  throws -> Int16  { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: Int32.Type)  throws -> Int32  { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: Int64.Type)  throws -> Int64  { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: UInt.Type)   throws -> UInt   { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: UInt8.Type)  throws -> UInt8  { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { recorder.recordSingle(.int64,   nullable: false); return 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        recorder.recordSingle(logicalType(for: T.self), nullable: false)
        return try makeDummy(T.self, key: "value", depth: depth + 1)
    }
}

// MARK: - Dummy value construction (satisfies return types; no recording)

fileprivate func makeDummy<T: Decodable>(_ type: T.Type, key: String, depth: Int) throws -> T {
    if depth > 32 { throw ParquetSchemaError.tooDeep(key: key) }
    return try T(from: DummyDecoder(depth: depth))
}

fileprivate final class DummyDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let depth: Int
    init(depth: Int) { self.depth = depth }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(DummyKeyed<Key>(depth: depth))
    }
    func unkeyedContainer() -> UnkeyedDecodingContainer { EmptyUnkeyed() }
    func singleValueContainer() -> SingleValueDecodingContainer { DummySingle(depth: depth) }
}

// Produces zero-values; `decodeNil` returns true so optionals collapse to nil
// and recursion terminates quickly.
fileprivate struct DummyKeyed<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let depth: Int
    var codingPath: [CodingKey] = []
    var allKeys: [Key] = []
    func contains(_ key: Key) -> Bool { true }
    func decodeNil(forKey key: Key) throws -> Bool { true }

    func decode(_ type: Bool.Type,   forKey key: Key) throws -> Bool   { false }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { "" }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { 0 }
    func decode(_ type: Float.Type,  forKey key: Key) throws -> Float  { 0 }
    func decode(_ type: Int.Type,    forKey key: Key) throws -> Int    { 0 }
    func decode(_ type: Int8.Type,   forKey key: Key) throws -> Int8   { 0 }
    func decode(_ type: Int16.Type,  forKey key: Key) throws -> Int16  { 0 }
    func decode(_ type: Int32.Type,  forKey key: Key) throws -> Int32  { 0 }
    func decode(_ type: Int64.Type,  forKey key: Key) throws -> Int64  { 0 }
    func decode(_ type: UInt.Type,   forKey key: Key) throws -> UInt   { 0 }
    func decode(_ type: UInt8.Type,  forKey key: Key) throws -> UInt8  { 0 }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try makeDummy(T.self, key: key.stringValue, depth: depth + 1)
    }

    func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type, forKey key: Key) throws -> KeyedDecodingContainer<NK> {
        KeyedDecodingContainer(DummyKeyed<NK>(depth: depth + 1))
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { EmptyUnkeyed() }
    func superDecoder() throws -> Decoder { DummyDecoder(depth: depth + 1) }
    func superDecoder(forKey key: Key) throws -> Decoder { DummyDecoder(depth: depth + 1) }
}

fileprivate struct DummySingle: SingleValueDecodingContainer {
    let depth: Int
    var codingPath: [CodingKey] = []
    func decodeNil() -> Bool { true }
    func decode(_ type: Bool.Type)   throws -> Bool   { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type)  throws -> Float  { 0 }
    func decode(_ type: Int.Type)    throws -> Int    { 0 }
    func decode(_ type: Int8.Type)   throws -> Int8   { 0 }
    func decode(_ type: Int16.Type)  throws -> Int16  { 0 }
    func decode(_ type: Int32.Type)  throws -> Int32  { 0 }
    func decode(_ type: Int64.Type)  throws -> Int64  { 0 }
    func decode(_ type: UInt.Type)   throws -> UInt   { 0 }
    func decode(_ type: UInt8.Type)  throws -> UInt8  { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try makeDummy(T.self, key: "value", depth: depth + 1)
    }
}

// Empty unkeyed container: arrays decode to []; terminates recursion.
fileprivate struct EmptyUnkeyed: UnkeyedDecodingContainer {
    var codingPath: [CodingKey] = []
    var count: Int? { 0 }
    var isAtEnd: Bool { true }
    var currentIndex: Int { 0 }

    mutating func decodeNil() throws -> Bool { true }
    mutating func decode(_ type: Bool.Type)   throws -> Bool   { false }
    mutating func decode(_ type: String.Type) throws -> String { "" }
    mutating func decode(_ type: Double.Type) throws -> Double { 0 }
    mutating func decode(_ type: Float.Type)  throws -> Float  { 0 }
    mutating func decode(_ type: Int.Type)    throws -> Int    { 0 }
    mutating func decode(_ type: Int8.Type)   throws -> Int8   { 0 }
    mutating func decode(_ type: Int16.Type)  throws -> Int16  { 0 }
    mutating func decode(_ type: Int32.Type)  throws -> Int32  { 0 }
    mutating func decode(_ type: Int64.Type)  throws -> Int64  { 0 }
    mutating func decode(_ type: UInt.Type)   throws -> UInt   { 0 }
    mutating func decode(_ type: UInt8.Type)  throws -> UInt8  { 0 }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try makeDummy(T.self, key: "element", depth: 1)
    }
    mutating func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type) throws -> KeyedDecodingContainer<NK> {
        KeyedDecodingContainer(DummyKeyed<NK>(depth: 1))
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { EmptyUnkeyed() }
    mutating func superDecoder() throws -> Decoder { DummyDecoder(depth: 1) }
}

// MARK: - Shredding with a Codable-derived schema

public extension JsonElement {
    /// Shred this element using the schema derived from `type` (types,
    /// nullability, and column order come from the Swift type, not the data).
    ///
    /// The data is expected to satisfy the type: non-optional fields should be
    /// present and non-null (a null in a REQUIRED column cannot be represented
    /// in Parquet).
    func toParquetTable<T: Decodable>(matching type: T.Type,
                                      options: ParquetShredOptions = ParquetShredOptions()) throws -> ParquetTable {
        let fields = try ParquetCodableSchema.columns(for: type, scalarColumnName: options.scalarColumnName)
        let plan = ParquetShredder.plan(fields: fields, for: self, options: options)
        return ParquetTable(rowCount: plan.rowCount,
                            columns: ParquetShredder.materialize(plan, rowStart: 0, rowEnd: plan.rowCount))
    }

    /// Stream this element to a sink using the schema derived from `type`.
    func writeParquet<T: Decodable>(to sink: ParquetSink,
                                    matching type: T.Type,
                                    shredOptions: ParquetShredOptions = ParquetShredOptions(),
                                    writeOptions: ParquetWriteOptions = ParquetWriteOptions()) throws {
        let fields = try ParquetCodableSchema.columns(for: type, scalarColumnName: shredOptions.scalarColumnName)
        let plan = ParquetShredder.plan(fields: fields, for: self, options: shredOptions)
        let writer = ParquetWriter(sink: sink, schema: plan.fields, options: writeOptions)
        let n = plan.rowCount
        var r = 0
        while r < n {
            let e = min(r + writeOptions.rowsPerRowGroup, n)
            writer.writeRowGroup(columns: ParquetShredder.materialize(plan, rowStart: r, rowEnd: e), rowCount: e - r)
            r = e
        }
        writer.finish()
    }
}

// MARK: - Streaming writer keyed to a Codable row type
//
// Configure once with a Codable row type; append rows (or batches) over time.
// Rows are buffered and flushed as a row group when they reach
// `writeOptions.rowsPerRowGroup`, so row groups stay a healthy size regardless
// of how the data trickles in. Values are copied on append, so it is safe to
// append from a short-lived `JsonElement` (e.g. inside `parsed`).

public final class ParquetStreamWriter {
    /// The fixed schema derived from the row type.
    public let schema: [ParquetField]

    private let accumulator: RowAccumulator
    private let writer: ParquetWriter
    private let rowsPerRowGroup: Int
    private var finished = false

    public init<T: Decodable>(sink: ParquetSink,
                              rowType: T.Type,
                              shredOptions: ParquetShredOptions = ParquetShredOptions(),
                              writeOptions: ParquetWriteOptions = ParquetWriteOptions()) throws {
        let fields = try ParquetCodableSchema.columns(for: T.self,
                                                      scalarColumnName: shredOptions.scalarColumnName)
        self.schema = fields
        self.accumulator = RowAccumulator(fields: fields, singleColumn: false)
        self.writer = ParquetWriter(sink: sink, schema: fields, options: writeOptions)
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
        writer.writeRowGroup(columns: group.columns, rowCount: group.rowCount)
    }

    /// Flush any buffered rows and write the file footer. Idempotent.
    public func finish() {
        guard !finished else { return }
        finished = true
        flush()
        writer.finish()
    }
}
