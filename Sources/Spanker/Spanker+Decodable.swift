import Foundation
import Hitch

public enum SpankerDecodingError: Error, CustomStringConvertible {
    case typeMismatch(expected: String, found: JsonType, path: String)
    case keyNotFound(key: String, path: String)
    case valueNotFound(type: String, path: String)
    case invalidDate(String, path: String)

    public var description: String {
        switch self {
        case .typeMismatch(let expected, let found, let path):
            return "expected \(expected) but found \(found) at \(path.isEmpty ? "<root>" : path)"
        case .keyNotFound(let key, let path):
            return "key '\(key)' not found at \(path.isEmpty ? "<root>" : path)"
        case .valueNotFound(let type, let path):
            return "expected \(type) but found null at \(path.isEmpty ? "<root>" : path)"
        case .invalidDate(let value, let path):
            return "could not parse date '\(value)' at \(path.isEmpty ? "<root>" : path)"
        }
    }
}

public extension JsonElement {
    /// Decode this element into a Decodable type without using JSONDecoder.
    func decoded<T: Decodable>() throws -> T {
        return try T(from: SpankerDecoder(element: self, codingPath: []))
    }
}

public extension Spanker {
    /// Parse and decode in one step. The decode happens inside the parse closure, so
    /// the returned value is fully materialised and safe to keep.
    static func decoded<T: Decodable>(hitch: Hitch) -> T? {
        return hitch.parsed { element in
            guard let element = element else { return nil }
            return try? element.decoded()
        }
    }

    static func decoded<T: Decodable>(halfhitch: HalfHitch) -> T? {
        return Spanker.parsed(halfhitch: halfhitch) { element in
            guard let element = element else { return nil }
            return try? element.decoded()
        }
    }

    static func decoded<T: Decodable>(data: Data) -> T? {
        return data.parsed { element in
            guard let element = element else { return nil }
            return try? element.decoded()
        }
    }

    static func decoded<T: Decodable>(string: String) -> T? {
        return string.parsed { element in
            guard let element = element else { return nil }
            return try? element.decoded()
        }
    }
}

fileprivate let spankerDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return formatter
}()

// MARK: - Decoder

fileprivate struct SpankerDecoder: Decoder {
    let element: JsonElement
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return [:] }

    var pathDescription: String {
        return codingPath.map { $0.stringValue }.joined(separator: ".")
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard element.type == .dictionary else {
            throw SpankerDecodingError.typeMismatch(expected: "object", found: element.type, path: pathDescription)
        }
        return KeyedDecodingContainer(SpankerKeyedContainer<Key>(element: element, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard element.type == .array else {
            throw SpankerDecodingError.typeMismatch(expected: "array", found: element.type, path: pathDescription)
        }
        return SpankerUnkeyedContainer(element: element, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SpankerSingleValueContainer(element: element, codingPath: codingPath)
    }
}

// MARK: - Shared value extraction

@inline(__always)
fileprivate func pathString(_ codingPath: [CodingKey]) -> String {
    return codingPath.map { $0.stringValue }.joined(separator: ".")
}

@inline(__always)
fileprivate func decodeValue<T: Decodable>(_ type: T.Type,
                                           _ element: JsonElement,
                                           _ codingPath: [CodingKey]) throws -> T {
    if type == Date.self {
        guard let raw = element.halfHitchValue?.toString() else {
            throw SpankerDecodingError.typeMismatch(expected: "date string", found: element.type, path: pathString(codingPath))
        }
        guard let date = spankerDateFormatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else {
            throw SpankerDecodingError.invalidDate(raw, path: pathString(codingPath))
        }
        return date as! T
    }
    if type == Data.self {
        guard let raw = element.halfHitchValue?.toString(),
              let data = Data(base64Encoded: raw) else {
            throw SpankerDecodingError.typeMismatch(expected: "base64 string", found: element.type, path: pathString(codingPath))
        }
        return data as! T
    }
    return try T(from: SpankerDecoder(element: element, codingPath: codingPath))
}

@inline(__always)
fileprivate func decodeInt(_ element: JsonElement, _ path: @autoclosure () -> String) throws -> Int {
    if let value = element.intValue { return value }
    if let value = element.doubleValue { return Int(value) }
    throw SpankerDecodingError.typeMismatch(expected: "integer", found: element.type, path: path())
}

@inline(__always)
fileprivate func decodeDouble(_ element: JsonElement, _ path: @autoclosure () -> String) throws -> Double {
    if let value = element.doubleValue { return value }
    if let value = element.intValue { return Double(value) }
    throw SpankerDecodingError.typeMismatch(expected: "double", found: element.type, path: path())
}

@inline(__always)
fileprivate func decodeBool(_ element: JsonElement, _ path: @autoclosure () -> String) throws -> Bool {
    if let value = element.boolValue { return value }
    if let value = element.intValue { return value != 0 }
    throw SpankerDecodingError.typeMismatch(expected: "bool", found: element.type, path: path())
}

@inline(__always)
fileprivate func decodeString(_ element: JsonElement, _ path: @autoclosure () -> String) throws -> String {
    guard let value = element.halfHitchValue else {
        throw SpankerDecodingError.typeMismatch(expected: "string", found: element.type, path: path())
    }
    return value.toString()
}

// MARK: - Keyed container

fileprivate struct SpankerKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let element: JsonElement
    let codingPath: [CodingKey]

    var pathDescription: String {
        return codingPath.map { $0.stringValue }.joined(separator: ".")
    }

    var allKeys: [Key] {
        return element.allKeys().compactMap { Key(stringValue: $0.toString()) }
    }

    func contains(_ key: Key) -> Bool {
        let child: JsonElement? = element[element: key.stringValue]
        return child != nil
    }

    private func child(_ key: Key) throws -> JsonElement {
        guard let child: JsonElement = element[element: key.stringValue] else {
            throw SpankerDecodingError.keyNotFound(key: key.stringValue, path: pathDescription)
        }
        return child
    }

    // Built only when an error is actually thrown. Doing this eagerly on every
    // primitive decode cost a String allocation per field and dominated the
    // decoder's runtime.
    private func path(_ key: Key) -> String {
        return (codingPath + [key]).map { $0.stringValue }.joined(separator: ".")
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let child: JsonElement = element[element: key.stringValue] else { return true }
        return child.type == .null
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { return try decodeBool(child(key), path(key)) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { return try decodeString(child(key), path(key)) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return try decodeDouble(child(key), path(key)) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { return Float(try decodeDouble(child(key), path(key))) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { return try decodeInt(child(key), path(key)) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { return Int8(try decodeInt(child(key), path(key))) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { return Int16(try decodeInt(child(key), path(key))) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { return Int32(try decodeInt(child(key), path(key))) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { return Int64(try decodeInt(child(key), path(key))) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { return UInt(try decodeInt(child(key), path(key))) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { return UInt8(try decodeInt(child(key), path(key))) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return UInt16(try decodeInt(child(key), path(key))) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return UInt32(try decodeInt(child(key), path(key))) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return UInt64(try decodeInt(child(key), path(key))) }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try decodeValue(type, child(key), codingPath + [key])
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard let child: JsonElement = element[element: key.stringValue], child.type != .null else { return nil }
        return try decodeValue(type, child, codingPath + [key])
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type,
                                               forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try SpankerDecoder(element: child(key), codingPath: codingPath + [key]).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try SpankerDecoder(element: child(key), codingPath: codingPath + [key]).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return SpankerDecoder(element: element, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        return SpankerDecoder(element: try child(key), codingPath: codingPath + [key])
    }
}

// MARK: - Unkeyed container

fileprivate struct SpankerIndexKey: CodingKey {
    let intValue: Int?
    var stringValue: String { return "[\(intValue ?? -1)]" }
    init?(stringValue: String) { return nil }
    init(intValue: Int) { self.intValue = intValue }
}

fileprivate struct SpankerUnkeyedContainer: UnkeyedDecodingContainer {
    let element: JsonElement
    let codingPath: [CodingKey]
    var currentIndex: Int = 0

    var count: Int? { return element.allValues().count }
    var isAtEnd: Bool { return currentIndex >= (count ?? 0) }

    private mutating func next() throws -> (JsonElement, [CodingKey]) {
        let values = element.allValues()
        guard currentIndex < values.count else {
            throw SpankerDecodingError.valueNotFound(type: "element",
                                                     path: codingPath.map { $0.stringValue }.joined(separator: "."))
        }
        let path = codingPath + [SpankerIndexKey(intValue: currentIndex)]
        let value = values[currentIndex]
        currentIndex += 1
        return (value, path)
    }

    mutating func decodeNil() throws -> Bool {
        let values = element.allValues()
        guard currentIndex < values.count else { return true }
        if values[currentIndex].type == .null { currentIndex += 1; return true }
        return false
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { let (e, p) = try next(); return try decodeBool(e, pathString(p)) }
    mutating func decode(_ type: String.Type) throws -> String { let (e, p) = try next(); return try decodeString(e, pathString(p)) }
    mutating func decode(_ type: Double.Type) throws -> Double { let (e, p) = try next(); return try decodeDouble(e, pathString(p)) }
    mutating func decode(_ type: Float.Type) throws -> Float { let (e, p) = try next(); return Float(try decodeDouble(e, pathString(p))) }
    mutating func decode(_ type: Int.Type) throws -> Int { let (e, p) = try next(); return try decodeInt(e, pathString(p)) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { return Int8(try decode(Int.self)) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { return Int16(try decode(Int.self)) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { return Int32(try decode(Int.self)) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { return Int64(try decode(Int.self)) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { return UInt(try decode(Int.self)) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { return UInt8(try decode(Int.self)) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { return UInt16(try decode(Int.self)) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { return UInt32(try decode(Int.self)) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { return UInt64(try decode(Int.self)) }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let (child, path) = try next()
        return try decodeValue(type, child, path)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let (child, path) = try next()
        return try SpankerDecoder(element: child, codingPath: path).container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let (child, path) = try next()
        return try SpankerDecoder(element: child, codingPath: path).unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        let (child, path) = try next()
        return SpankerDecoder(element: child, codingPath: path)
    }
}

// MARK: - Single value container

fileprivate struct SpankerSingleValueContainer: SingleValueDecodingContainer {
    let element: JsonElement
    let codingPath: [CodingKey]

    var pathDescription: String {
        return codingPath.map { $0.stringValue }.joined(separator: ".")
    }

    func decodeNil() -> Bool { return element.type == .null }

    func decode(_ type: Bool.Type) throws -> Bool { return try decodeBool(element, pathDescription) }
    func decode(_ type: String.Type) throws -> String { return try decodeString(element, pathDescription) }
    func decode(_ type: Double.Type) throws -> Double { return try decodeDouble(element, pathDescription) }
    func decode(_ type: Float.Type) throws -> Float { return Float(try decodeDouble(element, pathDescription)) }
    func decode(_ type: Int.Type) throws -> Int { return try decodeInt(element, pathDescription) }
    func decode(_ type: Int8.Type) throws -> Int8 { return Int8(try decodeInt(element, pathDescription)) }
    func decode(_ type: Int16.Type) throws -> Int16 { return Int16(try decodeInt(element, pathDescription)) }
    func decode(_ type: Int32.Type) throws -> Int32 { return Int32(try decodeInt(element, pathDescription)) }
    func decode(_ type: Int64.Type) throws -> Int64 { return Int64(try decodeInt(element, pathDescription)) }
    func decode(_ type: UInt.Type) throws -> UInt { return UInt(try decodeInt(element, pathDescription)) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { return UInt8(try decodeInt(element, pathDescription)) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return UInt16(try decodeInt(element, pathDescription)) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return UInt32(try decodeInt(element, pathDescription)) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return UInt64(try decodeInt(element, pathDescription)) }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try decodeValue(type, element, codingPath)
    }
}
