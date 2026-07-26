import Foundation
import Hitch

fileprivate func newDateFormatter(utc: Bool) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    if utc {
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
    } else {
        formatter.timeZone = TimeZone.current
    }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return formatter
}
fileprivate let iso8601DateFormatterUTC = newDateFormatter(utc: true)


fileprivate typealias JsonAny = Any?
fileprivate typealias JsonArray = [JsonAny]
fileprivate typealias JsonDictionary = [String: JsonAny]


prefix operator ^
public prefix func ^ (value: JsonElementable?) -> JsonElement {
    return JsonElement(unknown: value)
}

public extension Data {

    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(data: self, callback)
    }
}

public extension Hitch {

    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(hitch: self, callback)
    }
}

public extension HalfHitch {

    func parsed<T>(_ callback: (JsonElement?) -> T?) -> T? {
        return Spanker.parsed(halfhitch: self, callback)
    }
}

public extension String {

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

    public func toJsonElement() -> JsonElement {
        return self
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(string: HalfHitch(string: self))
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(string: HalfHitch(stringLiteral: self))
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(string: self.halfhitch())
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(string: self)
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(int: self)
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(double: self)
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(bool: self)
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement.null()
    }


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

    public func toJsonElement() -> JsonElement {
        return JsonElement(double: doubleValue)
    }


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
        
        internal var index = -1

        
        internal var countMinusOne = 0

        
        internal let keyArray: [HalfHitch]

        
        internal let valueArray: [JsonElement]

        
        internal init(keyArray: [HalfHitch], valueArray: [JsonElement]) {
            self.keyArray = keyArray
            self.valueArray = valueArray
            countMinusOne = valueArray.count - 1
        }

    
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
        
        internal var index = -1

        
        internal let countMinusOne: Int

        
        internal let keyArray: [HalfHitch]

        
        internal init(keyArray: [HalfHitch]) {
            self.keyArray = keyArray
            countMinusOne = keyArray.count - 1
        }

    
        public mutating func next() -> HalfHitch? {
            guard index < countMinusOne else { return nil }
            index += 1
            return keyArray[index]
        }
    }

    public struct ValuesIterator: Sequence, IteratorProtocol {
        
        internal var index = -1

        
        internal let countMinusOne: Int

        
        internal let valueArray: [JsonElement]

        
        internal init(valueArray: [JsonElement]) {
            self.valueArray = valueArray
            countMinusOne = valueArray.count - 1
        }

    
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


    public var type: JsonType {
        return internalType
    }


    public var iterWalking: WalkingIterator {
        return WalkingIterator(keyArray: keyArray, valueArray: valueArray)
    }


    public var iterKeys: KeysIterator {
        return KeysIterator(keyArray: keyArray)
    }


    public var iterValues: ValuesIterator {
        return ValuesIterator(valueArray: valueArray)
    }


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


    public var count: Int {
        if internalType == .string || internalType == .regex {
            return valueString.count
        }
        return valueArray.count
    }


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


    public func contains(key: HalfHitch) -> Bool {
        guard internalType == .dictionary else { return false }
        return keyArray.contains(key)
    }


    public func contains(key: Hitch) -> Bool {
        guard internalType == .dictionary else { return false }
        for existingKey in keyArray where existingKey == key {
            return true
        }
        return false
    }


    public func replace(with other: JsonElement) {
        self.internalType = other.internalType
        self.valueString = other.valueString
        self.valueInt = other.valueInt
        self.valueDouble = other.valueDouble
        self.valueArray = other.valueArray
        self.keyArray = other.keyArray
    }


    public func replace(at: Int, value: JsonElementable?) {
        guard internalType == .array else { return }
        guard at >= 0 && at < valueArray.count else { return }
        valueArray[at] = JsonElement(unknown: value)
    }


    public func append(value: JsonElementable?) {
        guard internalType == .array else { return }
        valueArray.append(JsonElement(unknown: value))
    }


    public func insert(value: JsonElementable?, at index: Int) {
        guard internalType == .array else { return }
        while valueArray.count <= index {
            valueArray.append(JsonElement.null())
        }
        valueArray.insert(JsonElement(unknown: value), at: index)
    }


    public func set(value: JsonElementable?, at index: Int) {
        guard internalType == .array else { return }
        while valueArray.count <= index {
            valueArray.append(JsonElement.null())
        }
        valueArray[index] = JsonElement(unknown: value)
    }


    public func rename(key: HalfHitch, with: HalfHitch) {
        guard internalType == .dictionary else { return }
        guard let index = keyArray.firstIndex(of: key) else { return }
        keyArray[index] = with
    }


    public func set(key: HalfHitch,
                    value: JsonElementable?) {
        guard internalType == .dictionary else { return }
        set(key: key,
            element: value?.toJsonElement() ?? JsonElement.null())
    }


    public func remove(at: Int) {
        guard internalType == .array else { return }
        guard at >= 0 && at < valueArray.count else { return }
        valueArray.remove(at: at)
    }


    public func remove(key: HalfHitch) {
        guard internalType == .dictionary else { return }
        guard let index = keyArray.firstIndex(of: key) else { return }
        guard index >= 0 && index < valueArray.count else { return }
        keyArray.remove(at: index)
        valueArray.remove(at: index)
    }


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
    
    public init(unknown: JsonElementable) {
        internalType = .null
        unknown.fillJsonElement(internalType: &internalType,
                                valueInt: &valueInt,
                                valueDouble: &valueDouble,
                                valueString: &valueString,
                                valueArray: &valueArray,
                                keyArray: &keyArray)
    }
    
    public init(unknown: Any?) {
        internalType = .null
        guard let unknown = unknown else { return }
        
        switch unknown {
        case _ as NSNull:
            return
        case let value as Int:
            internalType = .int
            valueInt = value
        case let value as Double:
            internalType = .double
            valueDouble = value
        case let value as Float:
            internalType = .double
            valueDouble = Double(value)
        case let value as NSNumber:
            internalType = .double
            valueDouble = value.doubleValue
        case let value as Bool:
            internalType = .boolean
            valueInt = value == true ? 1 : 0
        case let value as Hitch:
            internalType = .string
            valueString = value.halfhitch()
        case let value as HalfHitch:
            internalType = .string
            valueString = value
        case let value as String:
            internalType = .string
            valueString = HalfHitch(string: value)
        case let value as JsonArray:
            create(array: value)
        case let value as JsonDictionary:
            create(dictionary: value)
        default:
            fatalError("internal error")
        }
    }
    
    fileprivate func create(array: Array<Any?>) {
        internalType = .array
                
        valueArray = array.map {
            if let element = $0 as? JsonElementable { return element.toJsonElement() }
            if let element = $0 as? JsonElementableArray { return element.toJsonElement() }
            if let element = $0 as? JsonElementableDictionary { return element.toJsonElement() }
            return JsonElement(unknown: $0)
        }
    }
    
    fileprivate func create(dictionary: Dictionary<AnyHashable, Any?>) {
        internalType = .dictionary
        valueArray = []
        keyArray = []
        for (key, value) in dictionary {
            guard let keyString = key as? String else { continue }
            keyArray.append(HalfHitch(string: keyString))
            
            if let value = value as? JsonElementable {
                valueArray.append(value.toJsonElement())
            } else if let value = value as? JsonElementableArray {
                valueArray.append(value.toJsonElement())
            } else if let value = value as? JsonElementableDictionary {
                valueArray.append(value.toJsonElement())
            } else if let value = value as? [AnyHashable: Any?] {
                valueArray.append(JsonElement(unknown: value))
            } else {
                valueArray.append(JsonElement.null())
            }
        }
    }


    public var description: String {
        let count = estimatedExportCount(pretty: false,
                                         level: 0,
                                         inCount: 0)
        return exportTo(hitch: Hitch(capacity: count),
                        pretty: false,
                        level: 0).description
    }


    public func toString(pretty: Bool = false) -> String {
        let count = estimatedExportCount(pretty: pretty,
                                         level: 0,
                                         inCount: 0)
        return exportTo(hitch: Hitch(capacity: count),
                        pretty: pretty,
                        level: 0).toString()
    }


    public func toHitch(pretty: Bool = false) -> Hitch {
        let count = estimatedExportCount(pretty: pretty,
                                         level: 0,
                                         inCount: 0)
        return exportTo(hitch: Hitch(capacity: count),
                        pretty: pretty,
                        level: 0)
    }

    // MARK: - Internal

    
    internal var internalType: JsonType

    
    internal var valueString: HalfHitch = HalfHitch.empty
    
    internal var valueInt: Int = 0
    
    internal var valueDouble: Double = 0.0
    
    internal var valueArray: [JsonElement] = []
    
    internal var keyArray: [HalfHitch] = []
    
    public func allValues() -> [JsonElement] {
        return valueArray
    }
    
    public func allKeys() -> [HalfHitch] {
        return keyArray
    }


    internal var valueBool: Bool {
        return valueInt == 0 ? false : true
    }


    internal func append(value: JsonElement) {
        guard internalType == .array else { return }
        valueArray.append(value)
    }


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

    
    init() {
        internalType = .null
    }

    
    init(string: HalfHitch) {
        internalType = .string
        valueString = string
    }
    
    
    init(regex: HalfHitch) {
        internalType = .regex
        valueString = regex
    }

    
    init(bool: Bool) {
        internalType = .boolean
        valueInt = bool == true ? 1 : 0
    }

    
    init(int: Int) {
        internalType = .int
        valueInt = int
    }

    
    init(double: Double) {
        internalType = .double
        valueDouble = double
    }

    
    init(array: [JsonElement]) {
        internalType = .array
        valueArray = array
        valueArray.reserveCapacity(32)
    }

    
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

    public func exportTo(hitch: Hitch) -> Hitch {
        return exportTo(hitch: hitch,
                        pretty: false,
                        level: 0)
    }

    @discardableResult

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
                // Key needs to be escaped for JSON
                hitch.append(keyArray[idx].escaped(unicode: false, singleQuotes: false))
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
    
    public func estimatedExportCount(pretty: Bool,
                                     level: Int,
                                     inCount: Int) -> Int {
        var count = inCount
        
        func nextLine(offset: Int) {
            guard pretty else { return }
            count += 1
            for _ in 0..<(level+offset) {
                count += 4
            }
        }
        
        switch internalType {
        case .null:
            count += 4
        case .boolean:
            if valueInt != 0 {
                count += 4
            } else {
                count += 5
            }
        case .string:
            count += 2 + valueString.count * 2
        case .regex:
            count += valueString.count * 2
        case .int:
            count += 32
        case .double:
            count += 32
        case .array:
            count += 2
            for idx in 0..<valueArray.count {
                nextLine(offset: 1)
                count = valueArray[idx].estimatedExportCount(pretty: pretty,
                                                             level: level + 1,
                                                             inCount: count)
                if idx < valueArray.count - 1 {
                    count += 1
                } else {
                    nextLine(offset: 0)
                }
            }
        case .dictionary:
            count += 2
            for idx in 0..<keyArray.count {
                nextLine(offset: 1)
                count += 3
                count += keyArray[idx].count
                if pretty {
                    count += 1
                }
                count = valueArray[idx].estimatedExportCount(pretty: pretty,
                                                             level: level + 1,
                                                             inCount: count)
                if idx < keyArray.count - 1 {
                    count += 1
                } else {
                    nextLine(offset: 0)
                }
            }
        }
        return count
    }
}

public enum Spanker {

    public static func parsed<T>(hitch: Hitch, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(hitch: hitch, callback)
    }


    public static func parsed<T>(halfhitch: HalfHitch, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(halfhitch: halfhitch, callback)
    }


    public static func parsed<T>(data: Data, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(data: data, callback)
    }


    public static func parsed<T>(string: String, _ callback: (JsonElement?) -> T?) -> T? {
        return Reader.parsed(string: string, callback)
    }


    public static func parse(hitch: Hitch?) -> JsonElement? {
        guard let hitch = hitch else { return nil }
        return Reader.parse(halfhitch: hitch.halfhitch())
    }
    
    public static func parse(halfhitch: HalfHitch?) -> JsonElement? {
        guard let halfhitch = halfhitch else { return nil }
        return Reader.parse(halfhitch: halfhitch)
    }
    
    public static func parse(data: Data?) -> JsonElement? {
        guard let data = data else { return nil }
        return Reader.parse(halfhitch: HalfHitch(data: data))
    }
    
    public static func parse(string: String?) -> JsonElement? {
        guard let string = string else { return nil }
        return Reader.parse(halfhitch: HalfHitch(string: string))
    }
    
    public static func parse(codable: Codable?) -> JsonElement? {
        guard let codable = codable else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(iso8601DateFormatterUTC)
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        guard let json = try? encoder.encode(codable) else { return nil }
        return Reader.parse(halfhitch: HalfHitch(data: json))
    }

}
