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

    public let type: JsonType

    public var valueString: HalfHitch = HalfHitch.empty
    public var valueInt: Int = 0
    public var valueDouble: Double = 0.0
    public var valueArray: [JsonElement] = []
    public var keyArray: [HalfHitch] = []

    @inlinable @inline(__always)
    public var valueBool: Bool {
        return valueInt == 0 ? false : true
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
            guard index >= 0 && index < valueArray.count else {
                return nil
            }
            return valueArray[index]
        }
    }

    @inlinable @inline(__always)
    public subscript (key: HalfHitch) -> JsonElement? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index]
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    public subscript (key: Hitch) -> JsonElement? {
        get {
            if let index = keyArray.firstIndex(of: key.halfhitch()) {
                return valueArray[index]
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    public func containsAll(keys: [HalfHitch]) -> Bool {
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
        return keyArray.contains(key)
    }

    @inlinable @inline(__always)
    public func contains(key: Hitch) -> Bool {
        for existingKey in keyArray where existingKey == key {
            return true
        }
        return false
    }

    @inlinable @inline(__always)
    internal func append(value: JsonElement) {
        valueArray.append(value)
    }

    @inlinable @inline(__always)
    internal func append(key: HalfHitch,
                         value: JsonElement) {
        keyArray.append(key)
        valueArray.append(value)
    }

    @inlinable @inline(__always)
    public init(unknown: Any?) {
        guard let unknown = unknown else { type = .null; return }

        switch unknown {
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
    public func json(hitch: Hitch) -> Hitch {
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

    @inlinable @inline(__always)
    public var description: String {
        return json(hitch: Hitch()).description
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
