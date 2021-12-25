import Foundation
import Hitch

public enum Spanker {

    public enum JsonType {
        case null
        case string
        case int
        case double
        case array
        case dictionary
    }

    public class JsonElement: CustomStringConvertible {
        public var description: String {
            switch type {
            case .null:
                return "null"
            case .string:
                guard let valueString = valueString else { return "null" }
                return "\"\(valueString.description)\""
            case .int:
                guard let valueInt = valueInt else { return "null" }
                return valueInt.description
            case .double:
                guard let valueDouble = valueDouble else { return "null" }
                return valueDouble.description
            case .array:
                guard let valueArray = valueArray else { return "null" }
                return "[\(valueArray.map { $0.description }.joined(separator: ","))]"
            case .dictionary:
                guard let valueDictionary = valueDictionary else { return "null" }
                return "{\(valueDictionary.map { "\"\($0.description)\":\($1.description)" }.joined(separator: ","))}"
            }
        }

        public let type: JsonType

        public var valueString: Hitch?
        public var valueInt: Int?
        public var valueDouble: Double?
        public var valueArray: [JsonElement]?
        public var valueDictionary: [Hitch: JsonElement]?

        internal var nameIdx: Int = 0
        internal var valueIdx: Int = 0

        internal func append(value: JsonElement) {
            valueArray?.append(value)
        }

        internal func append(key: Hitch,
                             value: JsonElement) {
            valueDictionary?[key] = value
        }

        init() {
            type = .null

            valueString = nil
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            valueDictionary = nil
        }

        init(string: Hitch) {
            type = .string

            valueString = string
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            valueDictionary = nil
        }

        init(int: Int) {
            type = .int

            valueString = nil
            valueInt = int
            valueDouble = nil
            valueArray = nil
            valueDictionary = nil
        }

        init(double: Double) {
            type = .double

            valueString = nil
            valueInt = nil
            valueDouble = double
            valueArray = nil
            valueDictionary = nil
        }

        init(array: [JsonElement]) {
            type = .array

            valueString = nil
            valueInt = nil
            valueDouble = nil
            valueArray = array
            valueDictionary = nil
        }

        init(dictionary: [Hitch: JsonElement]) {
            type = .dictionary

            valueString = nil
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            valueDictionary = dictionary
        }

        init?(parse: ParseValue) {
            valueString = nil
            valueInt = nil
            valueDouble = nil
            valueArray = nil
            valueDictionary = nil

            switch parse.type {
            case .null, .unknown:
                type = .null
                return
            case .int:
                type = .int
                return
            case .double:
                type = .double
                return
            case .element:
                type = .double
                return
            default:
                return nil
            }
        }
    }

    public static func parse(hitch: Hitch) -> JsonElement? {
        let reader = Reader(hitch: hitch)

        return reader.parse()
    }

    public static func parse(data: Data) -> JsonElement? {
        return parse(hitch: Hitch(data: data))
    }

    public static func parse(string: String) -> JsonElement? {
        return parse(hitch: Hitch(stringLiteral: string))
    }

}
