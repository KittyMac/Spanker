import Foundation
import Hitch

prefix operator ^
public prefix func ^ (value: JsonElementable?) -> JsonElement {
    return JsonElement(unknown: value)
}

public extension Data {
    @inlinable
    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(data: self, callback)
    }
}

public extension Hitch {
    @inlinable
    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(hitch: self, callback)
    }
}

public extension HalfHitch {
    @inlinable
    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(halfhitch: self, callback)
    }
}

public extension String {
    @inlinable
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
    case regex
}

// MARK: - JsonElementable

public protocol JsonElementable {
    func toJsonElement() -> JsonElement
    func fillJsonElement(internalType: inout JsonType,
                         valueInt: inout Int,
                         valueDouble: inout Double,
                         valueString: inout HalfHitch,
                         valueArray: inout [JsonElement],
                         keyArray: inout [HalfHitch])
}

extension JsonElement: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return self
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = self.internalType
        valueInt = self.valueInt
        valueDouble = self.valueDouble
        valueString = self.valueString
        valueArray = self.valueArray
        keyArray = self.keyArray
    }
}

extension String: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(string: HalfHitch(string: self))
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .string
        valueString = HalfHitch(string: self)
    }
}

extension StaticString: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(string: HalfHitch(stringLiteral: self))
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .string
        valueString = HalfHitch(stringLiteral: self)
    }
}

extension Hitch: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(string: self.halfhitch())
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .string
        valueString = self.halfhitch()
    }
}

extension HalfHitch: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(string: self)
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .string
        valueString = self
    }
}

extension Int: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(int: self)
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .int
        valueInt = self
    }
}

extension Double: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(double: self)
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .double
        valueDouble = self
    }
}

extension Bool: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(bool: self)
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .boolean
        valueInt = self == true ? 1 : 0
    }
}

extension NSNull: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement.null()
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .null
    }
}

extension NSNumber: JsonElementable {
    @inlinable
    public func toJsonElement() -> JsonElement {
        return JsonElement(double: doubleValue)
    }

    @inlinable
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .double
        valueDouble = self.doubleValue
    }
}

public typealias JsonElementableArray = [JsonElementable?]
extension JsonElementableArray: JsonElementable {
    public func toJsonElement() -> JsonElement {
        return JsonElement(array: map { $0?.toJsonElement() ?? JsonElement.null() })
    }
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .array
        valueArray = self.map { JsonElement(unknown: $0) }
    }
}

public typealias JsonElementableDictionary = [String: JsonElementable?]
extension JsonElementableDictionary: JsonElementable {
    public func toJsonElement() -> JsonElement {
        return JsonElement(keys: keys.map { HalfHitch(string: $0) },
                           values: values.map { $0?.toJsonElement() ?? JsonElement.null() })
    }
    public func fillJsonElement(internalType: inout JsonType,
                                valueInt: inout Int,
                                valueDouble: inout Double,
                                valueString: inout HalfHitch,
                                valueArray: inout [JsonElement],
                                keyArray: inout [HalfHitch]) {
        internalType = .dictionary
        keyArray = self.keys.map { HalfHitch(string: $0) }
        valueArray = self.values.map { JsonElement(unknown: $0) }
    }
}

// MARK: - JsonElement

// Note: this is 112 bytes according to the profiler
// Note: this is 96 bytes according to the profiler
// Note: this is 80 bytes according to the profiler
public final class JsonElement: CustomStringConvertible, Equatable {

    public struct WalkingIterator: Sequence, IteratorProtocol {
        @usableFromInline
        internal var index = -1

        @usableFromInline
        internal var countMinusOne = 0

        @usableFromInline
        internal let keyArray: [HalfHitch]

        @usableFromInline
        internal let valueArray: [JsonElement]

        @usableFromInline
        internal init(keyArray: [HalfHitch], valueArray: [JsonElement]) {
            self.keyArray = keyArray
            self.valueArray = valueArray
            countMinusOne = valueArray.count - 1
        }

        @inlinable
        public mutating func next() -> (HalfHitch, JsonElement)? {
            while true {
                guard index < countMinusOne else { return nil }
                index += 1
                let value = valueArray[index]
                if value.type == .dictionary || value.type == .array {
                    guard index < keyArray.count else {
                        return (HalfHitch(string: "\(index)"), value)
                    }
                    return (keyArray[index], value)
                }
            }
        }
    }

    public struct KeysIterator: Sequence, IteratorProtocol {
        @usableFromInline
        internal var index = -1

        @usableFromInline
        internal let countMinusOne: Int

        @usableFromInline
        internal let keyArray: [HalfHitch]

        @usableFromInline
        internal init(keyArray: [HalfHitch]) {
            self.keyArray = keyArray
            countMinusOne = keyArray.count - 1
        }

        @inlinable
        public mutating func next() -> HalfHitch? {
            guard index < countMinusOne else { return nil }
            index += 1
            return keyArray[index]
        }
    }

    public struct ValuesIterator: Sequence, IteratorProtocol {
        @usableFromInline
        internal var index = -1

        @usableFromInline
        internal let countMinusOne: Int

        @usableFromInline
        internal let valueArray: [JsonElement]

        @usableFromInline
        internal init(valueArray: [JsonElement]) {
            self.valueArray = valueArray
            countMinusOne = valueArray.count - 1
        }

        @inlinable
        public mutating func next() -> JsonElement? {
            guard index < countMinusOne else { return nil }
            index += 1
            return valueArray[index]
        }
    }

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
        case .regex:
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

    @inlinable
    public var type: JsonType {
        return internalType
    }

    @inlinable
    public var iterWalking: WalkingIterator {
        return WalkingIterator(keyArray: keyArray, valueArray: valueArray)
    }

    @inlinable
    public var iterKeys: KeysIterator {
        return KeysIterator(keyArray: keyArray)
    }

    @inlinable
    public var iterValues: ValuesIterator {
        return ValuesIterator(valueArray: valueArray)
    }

    @inlinable
    public var stringValue: String? {
        get {
            guard internalType == .string || internalType == .regex else { return nil }
            return valueString.toString()
        }
        set {
            guard internalType == .string || internalType == .regex else { return }
            guard let value = newValue else {
                valueString = HalfHitch.empty
                return
            }
            valueString = HalfHitch(string: value)
        }
    }

    @inlinable
    public var hitchValue: Hitch? {
        get {
            guard internalType == .string || internalType == .regex else { return nil }
            return valueString.hitch()
        }
        set {
            guard internalType == .string || internalType == .regex else { return }
            guard let value = newValue else {
                valueString = HalfHitch.empty
                return
            }
            valueString = value.halfhitch()
        }
    }

    @inlinable
    public var halfHitchValue: HalfHitch? {
        get {
            guard internalType == .string || internalType == .regex else { return nil }
            return valueString
        }
        set {
            guard internalType == .string || internalType == .regex else { return }
            guard let value = newValue else {
                valueString = HalfHitch.empty
                return
            }
            valueString = value
        }
    }

    @inlinable
    public var intValue: Int? {
        get {
            guard internalType == .int else { return nil }
            return valueInt
        }
        set {
            guard internalType == .int else { return }
            valueInt = newValue ?? 0
        }
    }

    @inlinable
    public var doubleValue: Double? {
        get {
            guard internalType == .double else { return nil }
            return valueDouble
        }
        set {
            guard internalType == .double else { return }
            valueDouble = newValue ?? 0.0
        }
    }

    @inlinable
    public var boolValue: Bool? {
        get {
            guard internalType == .boolean else { return nil }
            return valueInt != 0
        }
        set {
            guard internalType == .boolean else { return }
            guard let value = newValue else {
                valueInt = 0
                return
            }
            valueInt = value ? 1 : 0
        }
    }

    @inlinable
    public var values: JsonElement {
        get {
            switch internalType {
            case .array, .dictionary:
                return JsonElement(array: valueArray)
            case .int:
                return JsonElement(unknown: valueInt)
            case .boolean:
                return JsonElement(unknown: valueBool)
            case .double:
                return JsonElement(unknown: valueDouble)
            case .null:
                return JsonElement(unknown: nil)
            case .string:
                return JsonElement(unknown: valueString)
            case .regex:
                return JsonElement(unknown: valueString)
            }

        }
    }

    @inlinable
    public var count: Int {
        if internalType == .string || internalType == .regex {
            return valueString.count
        }
        return valueArray.count
    }

    @inlinable
    public func containsAll(keys: [HalfHitch]) -> Bool {
        guard internalType == .dictionary else { return false }

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

    @inlinable
    public func containsAll(keys: [Hitch]) -> Bool {
        guard internalType == .dictionary else { return false }

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

    @inlinable
    public func contains(key: HalfHitch) -> Bool {
        guard internalType == .dictionary else { return false }
        return keyArray.contains(key)
    }

    @inlinable
    public func contains(key: Hitch) -> Bool {
        guard internalType == .dictionary else { return false }
        for existingKey in keyArray where existingKey == key {
            return true
        }
        return false
    }

    @inlinable
    public func replace(with other: JsonElement) {
        self.internalType = other.internalType
        self.valueString = other.valueString
        self.valueInt = other.valueInt
        self.valueDouble = other.valueDouble
        self.valueArray = other.valueArray
        self.keyArray = other.keyArray
    }

    @inlinable
    public func replace(at: Int, value: JsonElementable?) {
        guard internalType == .array else { return }
        guard at >= 0 && at < valueArray.count else { return }
        valueArray[at] = JsonElement(unknown: value)
    }

    @inlinable
    public func append(value: JsonElementable?) {
        guard internalType == .array else { return }
        valueArray.append(JsonElement(unknown: value))
    }

    @inlinable
    public func insert(value: JsonElementable?, at index: Int) {
        guard internalType == .array else { return }
        while valueArray.count <= index {
            valueArray.append(JsonElement.null())
        }
        valueArray.insert(JsonElement(unknown: value), at: index)
    }

    @inlinable
    public func set(value: JsonElementable?, at index: Int) {
        guard internalType == .array else { return }
        while valueArray.count <= index {
            valueArray.append(JsonElement.null())
        }
        valueArray[index] = JsonElement(unknown: value)
    }

    @inlinable
    public func rename(key: HalfHitch, with: HalfHitch) {
        guard internalType == .dictionary else { return }
        guard let index = keyArray.firstIndex(of: key) else { return }
        keyArray[index] = with
    }

    @inlinable
    public func set(key: HalfHitch,
                    value: JsonElementable?) {
        guard internalType == .dictionary else { return }
        set(key: key,
            element: value?.toJsonElement() ?? JsonElement.null())
    }

    @inlinable
    public func remove(at: Int) {
        guard internalType == .array else { return }
        guard at >= 0 && at < valueArray.count else { return }
        valueArray.remove(at: at)
    }

    @inlinable
    public func remove(key: HalfHitch) {
        guard internalType == .dictionary else { return }
        guard let index = keyArray.firstIndex(of: key) else { return }
        guard index >= 0 && index < valueArray.count else { return }
        keyArray.remove(at: index)
        valueArray.remove(at: index)
    }

    @inlinable
    public func clean() {
        guard internalType == .dictionary || internalType == .array else { return }
        for idx in stride(from: count-1, through: 0, by: -1) {
            if valueArray[idx].type == .null {
                if idx < keyArray.count {
                    keyArray.remove(at: idx)
                }
                if idx < valueArray.count {
                    valueArray.remove(at: idx)
                }
            }
        }
    }

    public init(unknown: JsonElementable?) {
        internalType = .null
        unknown?.fillJsonElement(internalType: &internalType,
                                 valueInt: &valueInt,
                                 valueDouble: &valueDouble,
                                 valueString: &valueString,
                                 valueArray: &valueArray,
                                 keyArray: &keyArray)
    }

    @inlinable
    public var description: String {
        return exportTo(hitch: Hitch(capacity: 1024),
                        pretty: false,
                        level: 0).description
    }

    @inlinable
    public func toString(pretty: Bool = false) -> String {
        return exportTo(hitch: Hitch(capacity: 1024),
                        pretty: pretty,
                        level: 0).toString()
    }

    @inlinable
    public func toHitch(pretty: Bool = false) -> Hitch {
        return exportTo(hitch: Hitch(capacity: 1024),
                        pretty: pretty,
                        level: 0)
    }

    // MARK: - Internal

    @usableFromInline
    internal var internalType: JsonType

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

    @inlinable
    internal var valueBool: Bool {
        return valueInt == 0 ? false : true
    }

    @inlinable
    internal func append(value: JsonElement) {
        guard internalType == .array else { return }
        valueArray.append(value)
    }

    @inlinable
    internal func set(key: HalfHitch,
                      element: JsonElement) {
        guard internalType == .dictionary else { return }
        if let index = keyArray.firstIndex(of: key) {
            keyArray[index] = key
            valueArray[index] = element
        } else {
            keyArray.append(key)
            valueArray.append(element)
        }
    }

    @usableFromInline
    init() {
        internalType = .null
    }

    @usableFromInline
    init(string: HalfHitch) {
        internalType = .string
        valueString = string
    }
    
    @usableFromInline
    init(regex: HalfHitch) {
        internalType = .regex
        valueString = regex
    }

    @usableFromInline
    init(bool: Bool) {
        internalType = .boolean
        valueInt = bool == true ? 1 : 0
    }

    @usableFromInline
    init(int: Int) {
        internalType = .int
        valueInt = int
    }

    @usableFromInline
    init(double: Double) {
        internalType = .double
        valueDouble = double
    }

    @usableFromInline
    init(array: [JsonElement]) {
        internalType = .array
        valueArray = array
        valueArray.reserveCapacity(32)
    }

    @usableFromInline
    init(keys: [HalfHitch],
         values: [JsonElement]) {
        internalType = .dictionary

        keyArray = keys
        keyArray.reserveCapacity(32)
        valueArray = values
        valueArray.reserveCapacity(32)
    }

    @discardableResult
    public func sortKeys() -> Self {
        guard type == .dictionary || type == .array else { return self }
        for value in iterValues {
            if value.type == .dictionary || value.type == .array {
                value.sortKeys()
            }
        }
        if type == .dictionary {
            let combined = zip(keyArray, valueArray).sorted { $0.0 < $1.0 }
            keyArray = combined.map { $0.0 }
            valueArray = combined.map { $0.1 }
        }
        return self
    }

    @discardableResult
    public func sortAll() -> Self {
        guard type == .dictionary || type == .array else { return self }

        for value in iterValues {
            value.sortAll()
        }

        if type == .dictionary {
            let combined = zip(keyArray, valueArray).sorted { $0.0 < $1.0 }
            keyArray = combined.map { $0.0 }
            valueArray = combined.map { $0.1 }
        }
        if type == .array {
            // sorting an array of random stuff if a bit harder then sorting by keys. To do this we will:
            // serialize all values to their JSON strings
            // sort the JSON strings
            // deserialize all of the JSON strings
            let indexArray = 0..<valueArray.count
            let combined = zip(indexArray, valueArray.map { $0.toHitch() }).sorted { $0.1 < $1.1 }

            var newValueArray = [JsonElement]()

            for entry in combined {
                newValueArray.append(valueArray[entry.0])
            }

            valueArray = newValueArray
        }
        return self
    }

    @discardableResult
    public func sortArray(_ comparator: (JsonElement, JsonElement) -> Bool) -> Self {
        guard type == .array else { return self }
        valueArray.sort(by: comparator)
        return self
    }

    private var cachedReify: Any?
    public func reify(_ useNSNull: Bool = false) -> Any? {
        guard cachedReify == nil else { return cachedReify }

        switch internalType {
        case .null:
            if useNSNull == false {
                return nil
            }
            cachedReify = NSNull()
        case .boolean:
            cachedReify = valueInt != 0
        case .string:
            cachedReify = valueString.toString()
        case .regex:
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
    @inlinable
    public func exportTo(hitch: Hitch,
                         pretty: Bool,
                         level: Int) -> Hitch {
        func nextLine(offset: Int) {
            guard pretty else { return }
            hitch.append(.newLine)
            for _ in 0..<(level+offset) {
                hitch.append(.space)
                hitch.append(.space)
                hitch.append(.space)
                hitch.append(.space)
            }
        }
        
        switch internalType {
        case .null:
            hitch.append(.n)
            hitch.append(.u)
            hitch.append(.l)
            hitch.append(.l)
        case .boolean:
            if valueInt != 0 {
                hitch.append(.t)
                hitch.append(.r)
                hitch.append(.u)
                hitch.append(.e)
            } else {
                hitch.append(.f)
                hitch.append(.a)
                hitch.append(.l)
                hitch.append(.s)
                hitch.append(.e)
            }
        case .string:
            hitch.append(.doubleQuote)
            hitch.append(valueString.escaped(unicode: false, singleQuotes: false))
            hitch.append(.doubleQuote)
        case .regex:
            hitch.append(valueString)
        case .int:
            hitch.append(number: valueInt)
        case .double:
            hitch.append(double: valueDouble)
        case .array:
            hitch.append(.openBrace)
            for idx in 0..<valueArray.count {
                nextLine(offset: 1)
                valueArray[idx].exportTo(hitch: hitch,
                                         pretty: pretty,
                                         level: level + 1)
                if idx < valueArray.count - 1 {
                    hitch.append(.comma)
                } else {
                    nextLine(offset: 0)
                }
            }
            hitch.append(.closeBrace)
        case .dictionary:
            hitch.append(.openBracket)
            for idx in 0..<keyArray.count {
                nextLine(offset: 1)
                hitch.append(.doubleQuote)
                hitch.append(keyArray[idx])
                hitch.append(.doubleQuote)
                hitch.append(.colon)
                if pretty {
                    hitch.append(.space)
                }
                valueArray[idx].exportTo(hitch: hitch,
                                         pretty: pretty,
                                         level: level + 1)
                if idx < keyArray.count - 1 {
                    hitch.append(.comma)
                } else {
                    nextLine(offset: 0)
                }
            }
            hitch.append(.closeBracket)
        }
        return hitch
    }
}

public enum Spanker {

    @inlinable
    public static func parsed<T>(hitch: Hitch, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(hitch: hitch, callback)
    }

    @inlinable
    public static func parsed<T>(halfhitch: HalfHitch, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(halfhitch: halfhitch, callback)
    }

    @inlinable
    public static func parsed<T>(data: Data, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(data: data, callback)
    }

    @inlinable
    public static func parsed<T>(string: String, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(string: string, callback)
    }

    @inlinable
    public static func parse(halfhitch: HalfHitch) -> JsonElement? {
        return Reader.parse(halfhitch: halfhitch)
    }

}
