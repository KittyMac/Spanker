import Foundation
import Hitch

public extension Data {
    @inlinable @inline(__always)
    func parsed(_ callback: (Spanker.JsonElement?) -> Void) {
        Spanker.parsed(data: self, callback)
    }
}

public extension Hitch {
    @inlinable @inline(__always)
    func parsed(_ callback: (Spanker.JsonElement?) -> Void) {
        Spanker.parsed(hitch: self, callback)
    }
}

public extension String {
    @inlinable @inline(__always)
    func parsed(_ callback: (Spanker.JsonElement?) -> Void) {
        Spanker.parsed(string: self, callback)
    }
}

public enum Spanker {

    public enum JsonType {
        case null
        case boolean
        case string
        case int
        case double
        case array
        case dictionary
    }

    public final class JsonElement: CustomStringConvertible {
        static let null = JsonElement()
        static let `true` = JsonElement(bool: true)
        static let `false` = JsonElement(bool: false)
        static let intZero = JsonElement(int: 0)
        static let intOne = JsonElement(int: 1)
        static let intTwo = JsonElement(int: 2)
        static let intThree = JsonElement(int: 3)
        static let intFour = JsonElement(int: 4)
        static let intFive = JsonElement(int: 5)
        static let intSix = JsonElement(int: 6)
        static let intSeven = JsonElement(int: 7)
        static let intEight = JsonElement(int: 8)
        static let intNine = JsonElement(int: 9)
        static let doubleZero = JsonElement(double: 0.0)
        static let doubleOne = JsonElement(double: 1.0)
        static let doubleTwo = JsonElement(double: 2.0)
        static let doubleThree = JsonElement(double: 3.0)
        static let doubleFour = JsonElement(double: 4.0)
        static let doubleFive = JsonElement(double: 5.0)
        static let doubleSix = JsonElement(double: 6.0)
        static let doubleSeven = JsonElement(double: 7.0)
        static let doubleEight = JsonElement(double: 8.0)
        static let doubleNine = JsonElement(double: 9.0)
        static let emptyString = JsonElement(string: HalfHitch())
        static let emptyArray = JsonElement(array: [])
        static let emptyDictionary = JsonElement(keys: [], values: [])

        // deinit {
        //    print("deinit: type: \(type) value: \(self)")
        // }

        @discardableResult
        @inlinable @inline(__always)
        public func json(hitch: Hitch) -> Hitch {
            let appendNull: () -> Void = {
                hitch.append(UInt8.n)
                hitch.append(UInt8.u)
                hitch.append(UInt8.l)
                hitch.append(UInt8.l)
            }
            switch type {
            case .null:
                appendNull()
            case .boolean:
                if let valueBool = valueBool {
                    if valueBool {
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
                } else {
                    appendNull()
                }
            case .string:
                if let valueString = valueString {
                    hitch.append(UInt8.doubleQuote)
                    hitch.append(valueString)
                    hitch.append(UInt8.doubleQuote)
                } else {
                    appendNull()
                }
            case .int:
                if let valueInt = valueInt {
                    hitch.append(number: valueInt)
                } else {
                    appendNull()
                }
            case .double:
                if let valueDouble = valueDouble {
                    hitch.append(double: valueDouble)
                } else {
                    appendNull()
                }
            case .array:
                if let valueArray = valueArray {
                    hitch.append(UInt8.openBrace)
                    for idx in 0..<valueArray.count {
                        valueArray[idx].json(hitch: hitch)
                        if idx < valueArray.count - 1 {
                            hitch.append(UInt8.comma)
                        }
                    }
                    hitch.append(UInt8.closeBrace)
                } else {
                    appendNull()
                }
            case .dictionary:
                if let valueArray = valueArray,
                   let keyArray = keyArray {
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
                } else {
                    appendNull()
                }
            }
            return hitch
        }

        @inlinable @inline(__always)
        public var description: String {
            return json(hitch: Hitch()).description
        }

        public let type: JsonType

        public var valueString: HalfHitch?
        public var valueBool: Bool?
        public var valueInt: Int?
        public var valueDouble: Double?
        public var valueArray: [JsonElement]?
        public var keyArray: [HalfHitch]?

        @inlinable @inline(__always)
        internal func append(value: JsonElement) {
            valueArray?.append(value)
        }

        @inlinable @inline(__always)
        internal func append(key: HalfHitch,
                             value: JsonElement) {
            keyArray?.append(key)
            valueArray?.append(value)
        }

        @inlinable @inline(__always)
        init() {
            type = .null

            valueString = nil
            valueBool = nil
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            keyArray = nil
        }

        @inlinable @inline(__always)
        init(string: HalfHitch) {
            type = .string

            valueString = string
            valueBool = nil
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            keyArray = nil
        }

        @inlinable @inline(__always)
        init(bool: Bool) {
            type = .boolean

            valueString = nil
            valueBool = bool
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            keyArray = nil
        }

        @inlinable @inline(__always)
        init(int: Int) {
            type = .int

            valueString = nil
            valueBool = nil
            valueInt = int
            valueDouble = nil
            valueArray = nil
            keyArray = nil
        }

        @inlinable @inline(__always)
        init(double: Double) {
            type = .double

            valueString = nil
            valueBool = nil
            valueInt = nil
            valueDouble = double
            valueArray = nil
            keyArray = nil
        }

        @inlinable @inline(__always)
        init(array: [JsonElement]) {
            type = .array

            valueString = nil
            valueBool = nil
            valueInt = nil
            valueDouble = nil
            valueArray = array
            keyArray = nil
        }

        @inlinable @inline(__always)
        init(keys: [HalfHitch],
             values: [JsonElement]) {
            type = .dictionary

            valueString = nil
            valueBool = nil
            valueInt = nil
            valueDouble = nil
            valueArray = []
            keyArray = []
        }
    }

    @inlinable @inline(__always)
    public static func parsed(hitch: Hitch, _ callback: (JsonElement?) -> Void) {
        Reader.parsed(hitch: hitch, callback)
    }

    @inlinable @inline(__always)
    public static func parsed(data: Data, _ callback: (JsonElement?) -> Void) {
        Reader.parsed(data: data, callback)
    }

    @inlinable @inline(__always)
    public static func parsed(string: String, _ callback: (JsonElement?) -> Void) {
        Reader.parsed(string: string, callback)
    }

}
