import Foundation
import Hitch

public extension Data {
    @inlinable @inline(__always)
    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(data: self, callback)
    }
}

public extension Hitch {
    @inlinable @inline(__always)
    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(hitch: self, callback)
    }
}

public extension String {
    @inlinable @inline(__always)
    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(string: self, callback)
    }
}

public enum JsonType: UInt8 {
    case null
    case boolean
    case string
    case int
    case double
    case array
    case dictionary
}

// Note: this is 112 bytes according to the profiler
// Note: this is 96 bytes according to the profiler
// Note: this is 80 bytes according to the profiler
public final class JsonElement: CustomStringConvertible, Equatable {

    public struct KeysIterator: Sequence, IteratorProtocol {
        @usableFromInline
        internal var index = -1

        @usableFromInline
        internal let element: JsonElement

        @inlinable @inline(__always)
        internal init(element: JsonElement) {
            self.element = element
        }

        @inlinable @inline(__always)
        public mutating func next() -> HalfHitch? {
            guard element.type == .dictionary else { return nil }
            guard index < element.keyArray.count - 1 else { return nil }
            index += 1
            return element.keyArray[index]
        }
    }

    public struct ValuesIterator: Sequence, IteratorProtocol {
        @usableFromInline
        internal var index = 0

        @usableFromInline
        internal let element: JsonElement

        @inlinable @inline(__always)
        internal init(element: JsonElement) {
            self.index = 0
            self.element = element
        }

        @inlinable @inline(__always)
        public mutating func next() -> JsonElement? {
            guard element.type == .dictionary || element.type == .array else { return nil }
            guard index < element.valueArray.count - 1 else { return nil }
            index += 1
            return element.valueArray[index]
        }
    }

    @inlinable @inline(__always)
    public static func null() -> JsonElement {
        return JsonElement()
    }

    public static func == (lhs: JsonElement, rhs: JsonElement) -> Bool {
        guard lhs.type == rhs.type else { return false }
        switch lhs.type {
        case .null:
            return true
        case .boolean:
            return lhs.valueInt == rhs.valueInt
        case .string:
            return lhs.valueString == rhs.valueString
        case .int:
            return lhs.valueInt == rhs.valueInt
        case .double:
            return lhs.valueDouble == rhs.valueDouble
        case .array:
            return lhs.valueArray == rhs.valueArray
        case .dictionary:
            return lhs.keyArray == rhs.keyArray && lhs.valueArray == rhs.valueArray
        }
    }

    // MARK: - Public

    public let type: JsonType

    @inlinable @inline(__always)
    public var rawKeys: KeysIterator {
        return KeysIterator(element: self)
    }

    @inlinable @inline(__always)
    public var rawValues: ValuesIterator {
        return ValuesIterator(element: self)
    }

    @inlinable @inline(__always)
    public var stringValue: String? {
        get {
            guard type == .string else { return nil }
            return valueString.toString()
        }
        set {
            guard type == .string else { return }
            guard let value = newValue else {
                valueString = HalfHitch.empty
                return
            }
            valueString = value.hitch().halfhitch()
        }
    }

    @inlinable @inline(__always)
    public var intValue: Int? {
        get {
            guard type == .int else { return nil }
            return valueInt
        }
        set {
            guard type == .int else { return }
            valueInt = newValue ?? 0
        }
    }

    @inlinable @inline(__always)
    public var doubleValue: Double? {
        get {
            guard type == .double else { return nil }
            return valueDouble
        }
        set {
            guard type == .double else { return }
            valueDouble = newValue ?? 0.0
        }
    }

    @inlinable @inline(__always)
    public var boolValue: Bool? {
        get {
            guard type == .boolean else { return nil }
            return valueInt != 0
        }
        set {
            guard type == .boolean else { return }
            guard let value = newValue else {
                valueInt = 0
                return
            }
            valueInt = value ? 1 : 0
        }
    }

    @inlinable @inline(__always)
    public var count: Int {
        if type == .string {
            return valueString.count
        }
        return valueArray.count
    }

    @inlinable @inline(__always)
    public subscript (index: Int) -> JsonElement? {
        get {
            guard type == .array else { return nil }

            guard index >= 0 && index < valueArray.count else {
                return nil
            }
            return valueArray[index]
        }
    }

    @inlinable @inline(__always)
    public subscript (key: HalfHitch) -> JsonElement? {
        get {
            guard type == .dictionary else { return nil }

            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index]
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    public subscript (key: Hitch) -> JsonElement? {
        get {
            guard type == .dictionary else { return nil }

            if let index = keyArray.firstIndex(of: key.halfhitch()) {
                return valueArray[index]
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    public func containsAll(keys: [HalfHitch]) -> Bool {
        guard type == .dictionary else { return false }

        // returns true if all keys in keys are inside of the keyArray
        for keyA in keys {
            var keyExists = false
            for keyB in keyArray where keyA == keyB {
                keyExists = true
                break
            }
            if keyExists == false {
                return false
            }
        }
        return true
    }

    @inlinable @inline(__always)
    public func containsAll(keys: [Hitch]) -> Bool {
        guard type == .dictionary else { return false }

        // returns true if all keys in keys are inside of the keyArray
        for keyA in keys {
            var keyExists = false
            for keyB in keyArray where keyA == keyB {
                keyExists = true
                break
            }
            if keyExists == false {
                return false
            }
        }
        return true
    }

    @inlinable @inline(__always)
    public func contains(key: HalfHitch) -> Bool {
        guard type == .dictionary else { return false }
        return keyArray.contains(key)
    }

    @inlinable @inline(__always)
    public func contains(key: Hitch) -> Bool {
        guard type == .dictionary else { return false }
        for existingKey in keyArray where existingKey == key {
            return true
        }
        return false
    }

    @inlinable @inline(__always)
    public func replace(at: Int, value: Any?) {
        guard type == .array else { return }
        guard at >= 0 && at < valueArray.count else { return }
        valueArray[at] = JsonElement(unknown: value)
    }

    @inlinable @inline(__always)
    public func replace(key: Hitch,
                        value: Any?) {
        guard type == .dictionary else { return }
        guard let index = keyArray.firstIndex(of: key.halfhitch()) else { return }
        keyArray[index] = key.halfhitch()
        valueArray[index] = JsonElement(unknown: value)
    }

    @inlinable @inline(__always)
    public func replace(key: String,
                       value: Any?) {
        guard type == .dictionary else { return }
        replace(key: key, value: JsonElement(unknown: value))
    }

    @inlinable @inline(__always)
    public func replace(key: HalfHitch,
                       value: Any?) {
        guard type == .dictionary else { return }
        replace(key: key, value: JsonElement(unknown: value))
    }

    @inlinable @inline(__always)
    public func append(value: Any?) {
        guard type == .array else { return }
        append(value: JsonElement(unknown: value))
    }

    @inlinable @inline(__always)
    public func append(key: Hitch,
                       value: Any?) {
        guard type == .dictionary else { return }
        append(key: key, value: JsonElement(unknown: value))
    }

    @inlinable @inline(__always)
    public func append(key: String,
                       value: Any?) {
        guard type == .dictionary else { return }
        append(key: key, value: JsonElement(unknown: value))
    }

    @inlinable @inline(__always)
    public func append(key: HalfHitch,
                       value: Any?) {
        guard type == .dictionary else { return }
        append(key: key, value: JsonElement(unknown: value))
    }

    @inlinable @inline(__always)
    public func remove(at: Int) {
        guard type == .array else { return }
        guard at >= 0 && at < valueArray.count else { return }
        valueArray.remove(at: at)
    }

    @inlinable @inline(__always)
    public func remove(key: HalfHitch) {
        guard type == .dictionary else { return }
        guard let index = keyArray.firstIndex(of: key) else { return }
        guard index >= 0 && index < valueArray.count else { return }
        keyArray.remove(at: index)
        valueArray.remove(at: index)
    }

    @inlinable @inline(__always)
    public func remove(key: Hitch) {
        remove(key: key.halfhitch())
    }

    @inlinable @inline(__always)
    public func remove(key: String) {
        remove(key: key.hitch().halfhitch())
    }

    @inlinable @inline(__always)
    public init(unknown: Any?) {
        guard let unknown = unknown else { type = .null; return }

        switch unknown {
        case let value as JsonElement:
            type = value.type
            valueInt = value.valueInt
            valueDouble = value.valueDouble
            valueString = value.valueString
            valueArray = value.valueArray
            keyArray = value.keyArray
            return
        case _ as NSNull:
            type = .null
            return
        case let value as Int:
            type = .int
            valueInt = value
            return
        case let value as Double:
            type = .double
            valueDouble = value
            return
        case let value as Float:
            type = .double
            valueDouble = Double(value)
            return
        case let value as NSNumber:
            type = .double
            valueDouble = value.doubleValue
            return
        case let value as Bool:
            type = .boolean
            valueInt = value == true ? 1 : 0
            return
        case let value as Hitch:
            type = .string
            valueString = Hitch(value).halfhitch()
            return
        case let value as HalfHitch:
            type = .string
            valueString = Hitch(value.hitch()).halfhitch()
            return
        case let value as String:
            type = .string
            valueString = value.hitch().halfhitch()
            return
        case let value as [Any?]:
            type = .array
            valueArray = value.map { JsonElement(unknown: $0) }
            return
        case let dict as [String: [Any?]]:
            type = .dictionary

            keyArray.reserveCapacity(dict.count)
            valueArray.reserveCapacity(dict.count)
            for (key, value) in dict {
                keyArray.append(key.hitch().halfhitch())
                valueArray.append(JsonElement(unknown: value))
            }
            return
        default:
            type = .null
            return
        }
    }

    @inlinable @inline(__always)
    public var description: String {
        return json(hitch: Hitch()).description
    }

    // MARK: - Internal

    @usableFromInline
    internal var valueString: HalfHitch = HalfHitch.empty
    @usableFromInline
    internal var valueInt: Int = 0
    @usableFromInline
    internal var valueDouble: Double = 0.0
    @usableFromInline
    internal var valueArray: [JsonElement] = []
    @usableFromInline
    internal var keyArray: [HalfHitch] = []

    @inlinable @inline(__always)
    internal var valueBool: Bool {
        return valueInt == 0 ? false : true
    }

    @inlinable @inline(__always)
    internal func append(value: JsonElement) {
        valueArray.append(value)
    }

    @inlinable @inline(__always)
    internal func append(key: HalfHitch,
                         value: JsonElement) {
        guard type == .dictionary else { return }
        keyArray.append(key)
        valueArray.append(value)
    }

    @inlinable @inline(__always)
    init() {
        type = .null
    }

    @inlinable @inline(__always)
    init(string: HalfHitch) {
        type = .string
        valueString = string
    }

    @inlinable @inline(__always)
    init(bool: Bool) {
        type = .boolean
        valueInt = bool == true ? 1 : 0
    }

    @inlinable @inline(__always)
    init(int: Int) {
        type = .int
        valueInt = int
    }

    @inlinable @inline(__always)
    init(double: Double) {
        type = .double
        valueDouble = double
    }

    @inlinable @inline(__always)
    init(array: [JsonElement]) {
        type = .array
        valueArray = array
        valueArray.reserveCapacity(32)
    }

    @inlinable @inline(__always)
    init(keys: [HalfHitch],
         values: [JsonElement]) {
        type = .dictionary

        keyArray = keys
        keyArray.reserveCapacity(32)
        valueArray = values
        valueArray.reserveCapacity(32)
    }

    private var cachedReify: Any?
    public func reify(_ useNSNull: Bool = false) -> Any? {
        guard cachedReify == nil else { return cachedReify }

        switch type {
        case .null:
            if useNSNull == false {
                return nil
            }
            cachedReify = NSNull()
        case .boolean:
            cachedReify = valueInt != 0
        case .string:
            cachedReify = valueString.toString()
        case .int:
            cachedReify = valueInt
        case .double:
            cachedReify = valueDouble
        case .array:
            cachedReify = valueArray.map { $0.reify() }
        case .dictionary:
            cachedReify = [String: Any?](uniqueKeysWithValues: zip(
                keyArray.map { $0.toString() },
                valueArray.map { $0.reify() }
            ))
        }

        return cachedReify
    }

    @discardableResult
    @inlinable @inline(__always)
    internal func json(hitch: Hitch) -> Hitch {
        switch type {
        case .null:
            hitch.append(UInt8.n)
            hitch.append(UInt8.u)
            hitch.append(UInt8.l)
            hitch.append(UInt8.l)
        case .boolean:
            if valueInt != 0 {
                hitch.append(UInt8.t)
                hitch.append(UInt8.r)
                hitch.append(UInt8.u)
                hitch.append(UInt8.e)
            } else {
                hitch.append(UInt8.f)
                hitch.append(UInt8.a)
                hitch.append(UInt8.l)
                hitch.append(UInt8.s)
                hitch.append(UInt8.e)
            }
        case .string:
            hitch.append(UInt8.doubleQuote)
            hitch.append(valueString.escaped(unicode: false, singleQuotes: false))
            hitch.append(UInt8.doubleQuote)
        case .int:
            hitch.append(number: valueInt)
        case .double:
            hitch.append(double: valueDouble)
        case .array:
            hitch.append(UInt8.openBrace)
            for idx in 0..<valueArray.count {
                valueArray[idx].json(hitch: hitch)
                if idx < valueArray.count - 1 {
                    hitch.append(UInt8.comma)
                }
            }
            hitch.append(UInt8.closeBrace)
        case .dictionary:
            hitch.append(UInt8.openBracket)
            for idx in 0..<keyArray.count {
                hitch.append(UInt8.doubleQuote)
                hitch.append(keyArray[idx])
                hitch.append(UInt8.doubleQuote)
                hitch.append(UInt8.colon)
                valueArray[idx].json(hitch: hitch)
                if idx < keyArray.count - 1 {
                    hitch.append(UInt8.comma)
                }
            }
            hitch.append(UInt8.closeBracket)
        }
        return hitch
    }
}

public enum Spanker {

    @inlinable @inline(__always)
    public static func parsed<T>(hitch: Hitch, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(hitch: hitch, callback)
    }

    @inlinable @inline(__always)
    public static func parsed<T>(data: Data, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(data: data, callback)
    }

    @inlinable @inline(__always)
    public static func parsed<T>(string: String, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(string: string, callback)
    }

}
