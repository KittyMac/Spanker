import Foundation
import Hitch

extension Spanker {

    internal enum ValueType {
        case unknown
        case null
        case string
        case booleanTrue
        case booleanFalse
        case int
        case double
        case element
    }

    internal enum ElementType {
        case unknown
        case array
        case element
    }

    internal struct ParseValue {
        var type: ValueType = .unknown
        var nameIdx: Int = 0
        var endNameIdx: Int = 0
        var valueIdx: Int = 0

        mutating func clear() {
            self.type = .unknown
            self.nameIdx = 0
            self.valueIdx = 0
        }
    }

    @usableFromInline
    internal class Reader {
        @usableFromInline
        internal var json: Hitch

        public init(data: Data) {
            json = Hitch(data: data)
        }

        public init(string: String) {
            json = Hitch(stringLiteral: string)
        }

        public init(hitch: Hitch) {
            json = Hitch(hitch: hitch)
        }

        @inlinable @inline(__always)
        internal func strlen(at offset: Int) -> Int {
            var idx = offset
            while idx < json.count && json[idx] != 0 {
                idx += 1
            }
            return idx - offset
        }

        @inlinable @inline(__always)
        internal func strskip(offset: Int, _ params: UInt8...) -> Int {
            let end = json.count
            var idx = offset
            while idx < end {
                let char = json[idx]
                guard char != 0 else { break }
                guard params.contains(char) else { break }
                idx += 1
            }
            return idx
        }

        @inlinable @inline(__always)
        internal func strstrNoEscaped(offset: Int, find: UInt8) -> Int {
            // look forward for the matching character, not counting escaped versions of it
            let end = json.count
            var idx = offset
            while idx < end {
                let prev = idx > 0 ? json[idx-1] : 0
                let char = json[idx]
                guard char != 0 else { break }
                if char == find && prev != UInt8.backSlash {
                    return idx
                }
                idx += 1
            }
            return idx
        }

        @inlinable @inline(__always)
        internal func extract(start: Int, end: Int) -> Hitch? {
            return json.substring(start, end)
        }

        @usableFromInline
        internal func parse() -> JsonElement? {
            var currentIdx = 0
            var char: UInt8 = 0

            var elementStack: [JsonElement] = []

            var jsonAttribute = ParseValue()
            var rootElement: JsonElement?
            var jsonElement: JsonElement?

            let parseEndElement: () -> JsonElement? = {
                guard elementStack.count > 0 else { return nil }
                let myElement = elementStack.removeLast()

                if elementStack.count == 0 {
                    rootElement = myElement
                }

                return elementStack.last
            }

            let attributeAsHitch: (Int) -> JsonElement = { endIdx in
                guard let valueString = self.extract(start: jsonAttribute.valueIdx, end: endIdx) else { return JsonElement() }
                return JsonElement(string: valueString)
            }

            let attributeAsInt: (Int) -> JsonElement = { endIdx in
                guard let valueString = self.extract(start: jsonAttribute.valueIdx, end: endIdx) else { return JsonElement() }
                guard let value = valueString.toInt() else { return JsonElement() }
                return JsonElement(int: value)
            }

            let attributeAsDouble: (Int) -> JsonElement = { endIdx in
                guard let valueString = self.extract(start: jsonAttribute.valueIdx, end: endIdx) else { return JsonElement() }
                guard let value = valueString.toDouble() else { return JsonElement() }
                return JsonElement(double: value)
            }

            let attributeName: () -> Hitch? = {
                guard jsonAttribute.nameIdx > 0 else { return nil }
                guard jsonAttribute.endNameIdx > jsonAttribute.nameIdx else { return nil }
                return self.extract(start: jsonAttribute.nameIdx, end: jsonAttribute.endNameIdx)
            }

            let appendElement: (Hitch?, JsonElement) -> Void = { key, value in
                if let jsonElement = jsonElement {
                    if jsonElement.type == .array {
                        jsonElement.append(value: value)
                    } else if let key = key,
                              jsonElement.type == .dictionary {
                        jsonElement.append(key: key,
                                           value: value)
                    }
                } else {
                    rootElement = value
                    jsonElement = value
                }
            }

            // find next element start
            while true {
                currentIdx = strskip(offset: currentIdx, .space, .tab, .newLine, .carriageReturn, .comma)
                guard currentIdx < json.count else { break }

                // ok, so the main algorithm is fairly simple. At this point, we've identified the start of an object enclosure,
                // an array enclosure, or the start of a string make an element for this and put it on the stack
                var nextCurrentIdx = currentIdx + 1

                char = json[currentIdx]
                if char == .closeBracket || char == .closeBrace {
                    jsonElement = parseEndElement()
                } else if char == .openBracket || char == .openBrace {
                    // we've found the start of a new object
                    let nextElement = (char == .openBracket) ? JsonElement(keys: [], values: []) : JsonElement(array: [])

                    elementStack.append(nextElement)

                    // if there is a parent element, we need to add this to it
                    if let jsonElement = jsonElement {
                        if let name = attributeName() {
                            jsonElement.append(key: name, value: nextElement)
                        } else {
                            jsonElement.append(value: nextElement)
                        }
                        jsonAttribute.clear()
                    }

                    jsonElement = nextElement

                } else if jsonElement?.type == .dictionary && (char == .singleQuote || char == .doubleQuote) {
                    // We've found the name portion of a KVP

                    if jsonAttribute.nameIdx == 0 {
                        // Set the attribute name index
                        jsonAttribute.nameIdx = currentIdx + 1

                        // Find the name of the name string and null terminate it
                        nextCurrentIdx = strstrNoEscaped(offset: jsonAttribute.nameIdx, find: char)
                        jsonAttribute.endNameIdx = nextCurrentIdx

                        // Find the ':'
                        nextCurrentIdx = strstrNoEscaped(offset: nextCurrentIdx + 1, find: .colon) + 1

                        // skip whitespace
                        nextCurrentIdx = strskip(offset: nextCurrentIdx, .space, .tab, .newLine, .carriageReturn)

                        guard let key = attributeName() else { nextCurrentIdx += 1; continue }

                        // advance forward until we find the start of the next thing
                        var nextChar = json[nextCurrentIdx]
                        if nextChar == .singleQuote || nextChar == .doubleQuote {
                            // our value is a string
                            jsonAttribute.type = .string
                            jsonAttribute.valueIdx = nextCurrentIdx + 1

                            nextCurrentIdx = strstrNoEscaped(offset: jsonAttribute.valueIdx, find: nextChar)

                            appendElement(key, attributeAsHitch(nextCurrentIdx))

                            jsonAttribute.clear()

                            nextCurrentIdx += 1
                        } else if nextChar == .openBracket || nextChar == .openBrace {
                            // our value is an array or an object; we will process it next time through the main loop
                        } else if nextCurrentIdx < json.count - 3 &&
                                    nextChar == .n &&
                                    json[nextCurrentIdx+1] == .u &&
                                    json[nextCurrentIdx+2] == .l &&
                                    json[nextCurrentIdx+3] == .l {
                            // our value is null; pick up at the end of it
                            nextCurrentIdx += 4

                            appendElement(key, JsonElement())

                            jsonAttribute.clear()
                        } else {
                            // our value is likely a number; capture it then advance to the next ',' or '}' or whitespace
                            jsonAttribute.type = .int
                            jsonAttribute.valueIdx = nextCurrentIdx

                            while nextCurrentIdx < json.count &&
                                    nextChar != .space &&
                                    nextChar != .tab &&
                                    nextChar != .newLine &&
                                    nextChar != .carriageReturn &&
                                    nextChar != .comma &&
                                    nextChar != .closeBracket &&
                                    nextChar != .closeBrace {
                                if nextChar == .f &&
                                    nextCurrentIdx < json.count - 4 &&
                                    json[nextCurrentIdx+1] == .a &&
                                    json[nextCurrentIdx+2] == .l &&
                                    json[nextCurrentIdx+3] == .s &&
                                    json[nextCurrentIdx+4] == .e {
                                    jsonAttribute.type = .booleanFalse
                                    nextCurrentIdx += 5
                                    break
                                } else if nextChar == .t &&
                                    nextCurrentIdx < json.count - 3 &&
                                    json[nextCurrentIdx+1] == .r &&
                                    json[nextCurrentIdx+2] == .u &&
                                    json[nextCurrentIdx+3] == .e {
                                    jsonAttribute.type = .booleanTrue
                                    nextCurrentIdx += 4
                                    break
                                } else if nextChar == .dot {
                                    jsonAttribute.type = .double
                                }
                                nextCurrentIdx += 1
                                nextChar = json[nextCurrentIdx]
                            }

                            if jsonAttribute.type == .booleanTrue {
                                appendElement(key, JsonElement(bool: true))
                            } else if jsonAttribute.type == .booleanFalse {
                                appendElement(key, JsonElement(bool: false))
                            } else if jsonAttribute.type == .int {
                                appendElement(key, attributeAsInt(nextCurrentIdx))
                            } else if jsonAttribute.type == .double {
                                appendElement(key, attributeAsDouble(nextCurrentIdx))
                            }

                            jsonAttribute.clear()

                            if nextChar == .closeBrace {
                                jsonElement = parseEndElement()
                            }
                        }
                    }
                } else {
                    nextCurrentIdx = strskip(offset: currentIdx, .space, .tab, .newLine, .carriageReturn)

                    // advance forward until we find the start of the next thing
                    var nextChar = json[nextCurrentIdx]
                    if nextChar == .doubleQuote || nextChar == .singleQuote {
                        // our value is a string
                        jsonAttribute.type = .string
                        jsonAttribute.valueIdx = nextCurrentIdx + 1

                        nextCurrentIdx = strstrNoEscaped(offset: jsonAttribute.valueIdx, find: nextChar)

                        appendElement(nil, attributeAsHitch(nextCurrentIdx))

                        jsonAttribute.clear()

                        nextCurrentIdx += 1
                    } else if nextChar == .openBrace || nextChar == .openBracket {
                        // our value is an array or an object; we will process it next time through the main loop
                        nextCurrentIdx = nextCurrentIdx - 1
                    } else if nextCurrentIdx < json.count - 3 &&
                                nextChar == .n &&
                                json[nextCurrentIdx+1] == .u &&
                                json[nextCurrentIdx+2] == .l &&
                                json[nextCurrentIdx+3] == .l {
                        // our value is null; pick up at the end of it
                        nextCurrentIdx += 4

                        appendElement(nil, JsonElement())

                        jsonAttribute.clear()
                    } else {
                        // our value is likely a number; capture it then advance to the next ',' or '}' or whitespace
                        jsonAttribute.type = .int
                        jsonAttribute.valueIdx = nextCurrentIdx

                        while nextCurrentIdx < json.count &&
                                nextChar != .space &&
                                nextChar != .tab &&
                                nextChar != .newLine &&
                                nextChar != .carriageReturn &&
                                nextChar != .comma &&
                                nextChar != .closeBracket &&
                                nextChar != .closeBrace {
                            if nextChar == .f &&
                                nextCurrentIdx < json.count - 4 &&
                                json[nextCurrentIdx+1] == .a &&
                                json[nextCurrentIdx+2] == .l &&
                                json[nextCurrentIdx+3] == .s &&
                                json[nextCurrentIdx+4] == .e {
                                jsonAttribute.type = .booleanFalse
                                nextCurrentIdx += 5
                                break
                            } else if nextChar == .t &&
                                nextCurrentIdx < json.count - 3 &&
                                json[nextCurrentIdx+1] == .r &&
                                json[nextCurrentIdx+2] == .u &&
                                json[nextCurrentIdx+3] == .e {
                                jsonAttribute.type = .booleanTrue
                                nextCurrentIdx += 4
                                break
                            } else if nextChar == .dot {
                                jsonAttribute.type = .double
                            }
                            nextCurrentIdx += 1
                            nextChar = json[nextCurrentIdx]
                        }

                        if jsonAttribute.type == .booleanTrue {
                            appendElement(nil, JsonElement(bool: true))
                        } else if jsonAttribute.type == .booleanFalse {
                            appendElement(nil, JsonElement(bool: false))
                        } else if jsonAttribute.type == .int {
                            appendElement(nil, attributeAsInt(nextCurrentIdx))
                        } else if jsonAttribute.type == .double {
                            appendElement(nil, attributeAsDouble(nextCurrentIdx))
                        }

                        jsonAttribute.clear()

                        if nextChar == .closeBrace {
                            jsonElement = parseEndElement()
                        }
                    }
                }

                currentIdx = nextCurrentIdx
            }

            while elementStack.count > 0 {
                jsonElement = parseEndElement()
            }

            return rootElement
        }

    }
}
