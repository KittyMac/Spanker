import Foundation
import Hitch

private let emptyHalfHitch = HalfHitch()

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
        static let emptyString = JsonElement(string: emptyHalfHitch)
        static let emptyArray = JsonElement(array: [])
        static let emptyDictionary = JsonElement(keys: [], values: [])

        public let type: JsonType

        public var valueString: HalfHitch = emptyHalfHitch
        public var valueInt: Int = 0
        public var valueDouble: Double = 0.0
        public var valueArray: [JsonElement] = []
        public var keyArray: [HalfHitch] = []

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
        }

        @inlinable @inline(__always)
        init(keys: [HalfHitch],
             values: [JsonElement]) {
            type = .dictionary
            valueArray = []
            keyArray = []
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
                hitch.append(valueString)
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
