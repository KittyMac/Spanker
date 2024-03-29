import Foundation
import Hitch

@inlinable
internal func strskip(json: HalfHitch, offset: Int, _ params: UInt8...) -> Int {
    var idx = offset
    for char in json.stride(from: offset, to: json.count) {
        guard char != 0 else { break }
        guard params.contains(char) else { break }
        idx += 1
    }
    return idx
}

@inlinable
internal func strstrNoEscaped(json: HalfHitch,
                              offset: Int,
                              find: UInt8,
                              shouldUnescape: inout Bool) -> Int {
    // look forward for the matching character, not counting escaped versions of it
    var skipNext = false
    var idx = offset

    shouldUnescape = false
    for char in json.stride(from: offset, to: json.count) {
        guard char != 0 else { break }
        guard skipNext == false else {
            skipNext = false
            idx += 1
            continue
        }
        if char == .backSlash {
            shouldUnescape = true
            skipNext = true
            idx += 1
            continue
        }
        if char == find {
            return idx
        }
        idx += 1
    }
    return idx
}

@inlinable
internal func strstrRegex(json: HalfHitch,
                          offset: Int,
                          find: UInt8) -> Int {
    // look forward for the matching character, not counting escaped versions of it
    var skipNext = false
    var idx = offset

    var prev: UInt8 = 0
    for char in json.stride(from: offset, to: json.count) {
        guard char != 0 else { break }
        guard skipNext == false else {
            skipNext = false
            idx += 1
            prev = char
            continue
        }
        if char == find && prev != .backSlash {
            return idx
        }
        idx += 1
    }
    return idx
}

extension Spanker {

    internal enum ValueType {
        case unknown
        case null
        case string
        case regex
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
        var shouldUnescape = false

        mutating func clear() {
            self.type = .unknown
            self.nameIdx = 0
            self.valueIdx = 0
            self.shouldUnescape = false
        }
    }

    @usableFromInline
    internal enum Reader {

        @usableFromInline
        internal static func parsed<T>(hitch: Hitch, _ callback: (JsonElement?) -> T?) -> T? {
            return parsed(halfhitch: hitch.halfhitch(), callback)
        }

        @usableFromInline
        internal static func parsed<T>(string: String, _ callback: (JsonElement?) -> T?) -> T? {
            return parsed(halfhitch: HalfHitch(string: string), callback)
        }

        @usableFromInline
        internal static func parsed<T>(data: Data, _ callback: (JsonElement?) -> T?) -> T? {
            return HalfHitch.using(data: data) { json in
                return parsed(halfhitch: json, callback)
            }
        }

        @usableFromInline
        internal static func parsed<T>(halfhitch json: HalfHitch, _ callback: (JsonElement?) -> T?) -> T? {
            callback(parse(halfhitch: json))
        }

        @usableFromInline
        internal static func parse(halfhitch json: HalfHitch) -> JsonElement? {
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
                guard jsonAttribute.valueIdx < endIdx else { return JsonElement(string: HalfHitch()) }
                var valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx, to: endIdx)
                if jsonAttribute.shouldUnescape {
                    valueString = valueString.unicodeUnescaped()
                }
                return JsonElement(string: valueString)
            }
            
            let attributeAsRegex: (Int) -> JsonElement = { endIdx in
                guard jsonAttribute.valueIdx < endIdx else { return JsonElement(string: HalfHitch()) }
                let valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx-1, to: endIdx)
                return JsonElement(regex: valueString)
            }

            let attributeAsInt: (Int) -> JsonElement? = { endIdx in
                let valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx, to: endIdx)
                guard let value = valueString.toInt() else { return nil }
                return JsonElement(int: value)
            }

            let attributeAsDouble: (Int) -> JsonElement? = { endIdx in
                let valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx, to: endIdx)
                guard let value = valueString.toDouble() else { return nil }
                return JsonElement(double: value)
            }

            let attributeName: () -> HalfHitch? = {
                guard jsonAttribute.nameIdx > 0 else { return nil }
                var name = HalfHitch(source: json, from: jsonAttribute.nameIdx, to: jsonAttribute.endNameIdx)
                if jsonAttribute.shouldUnescape {
                    name = name.unicodeUnescaped()
                }
                return name
            }

            let appendElement: (HalfHitch?, JsonElement?) -> Void = { key, value in
                guard let value = value else { return }
                if let jsonElement = jsonElement {
                    if jsonElement.type == .array {
                        jsonElement.append(value: value)
                    } else if let key = key,
                              jsonElement.type == .dictionary {
                        jsonElement.set(key: key,
                                        value: value)
                    }
                } else {
                    rootElement = value
                    jsonElement = value
                }
            }

            if let raw = json.raw() {

                // find next element start
                while true {
                    currentIdx = strskip(json: json, offset: currentIdx, .space, .tab, .newLine, .carriageReturn, .comma)
                    guard currentIdx < json.count else { break }

                    // ok, so the main algorithm is fairly simple. At this point, we've identified the start of an object enclosure,
                    // an array enclosure, or the start of a string make an element for this and put it on the stack
                    var nextCurrentIdx = currentIdx + 1

                    char = raw[currentIdx]
                    if char == .closeBracket || char == .closeBrace {
                        jsonElement = parseEndElement()
                    } else if char == .openBracket || char == .openBrace {

                        let processElement: (JsonElement) -> Void = { nextElement in
                            elementStack.append(nextElement)

                            // if there is a parent element, we need to add this to it
                            if let jsonElement = jsonElement {
                                if let name = attributeName() {
                                    jsonElement.set(key: name, value: nextElement)
                                } else {
                                    jsonElement.append(value: nextElement)
                                }
                                jsonAttribute.clear()
                            }

                            jsonElement = nextElement
                        }

                        // fast path: is this an empty object or bracket?
                        let nextChar = raw[currentIdx + 1]
                        if nextChar == .closeBracket {
                            processElement(JsonElement(keys: [], values: []))
                        } else if nextChar == .closeBrace {
                            processElement(JsonElement(array: []))
                        } else if char == .openBracket {
                            processElement(JsonElement(keys: [], values: []))
                        } else {
                            processElement(JsonElement(array: []))
                        }

                    } else if jsonElement?.type == .dictionary && (char == .singleQuote || char == .doubleQuote) {
                        // We've found the name portion of a KVP

                        if jsonAttribute.nameIdx == 0 {
                            // Set the attribute name index
                            jsonAttribute.nameIdx = currentIdx + 1

                            // Find the name of the name string and null terminate it
                            var shouldUnescape = false
                            nextCurrentIdx = strstrNoEscaped(json: json,
                                                             offset: jsonAttribute.nameIdx,
                                                             find: .doubleQuote,
                                                             shouldUnescape: &shouldUnescape)
                            jsonAttribute.shouldUnescape = shouldUnescape
                            jsonAttribute.endNameIdx = nextCurrentIdx

                            // Find the ':'
                            nextCurrentIdx = strstrNoEscaped(json: json,
                                                             offset: nextCurrentIdx + 1,
                                                             find: .colon,
                                                             shouldUnescape: &shouldUnescape) + 1

                            // skip whitespace
                            nextCurrentIdx = strskip(json: json, offset: nextCurrentIdx, .space, .tab, .newLine, .carriageReturn)

                            // grab the name of the attribute
                            var key = HalfHitch(source: json, from: jsonAttribute.nameIdx, to: jsonAttribute.endNameIdx)
                            if jsonAttribute.shouldUnescape {
                                key = key.unicodeUnescaped()
                            }

                            // advance forward until we find the start of the next thing
                            var nextChar = raw[nextCurrentIdx]
                            
                            if nextChar == .forwardSlash {
                                // our value is a regex
                                jsonAttribute.type = .regex
                                jsonAttribute.valueIdx = nextCurrentIdx + 1

                                nextCurrentIdx = strstrRegex(json: json,
                                                             offset: jsonAttribute.valueIdx,
                                                             find: .forwardSlash)
                                
                                // consume the trailing forward slash
                                if json[nextCurrentIdx] == .forwardSlash {
                                    nextCurrentIdx += 1
                                }
                                
                                // handle regex flags
                                let flags: HalfHitch = "igm"
                                while flags.contains(json[nextCurrentIdx]) {
                                    nextCurrentIdx += 1
                                }

                                appendElement(key, attributeAsRegex(nextCurrentIdx))

                                jsonAttribute.clear()
                            } else if nextChar == .doubleQuote {
                                // our value is a string
                                jsonAttribute.type = .string
                                jsonAttribute.valueIdx = nextCurrentIdx + 1

                                var shouldUnescape = false
                                nextCurrentIdx = strstrNoEscaped(json: json,
                                                                 offset: jsonAttribute.valueIdx,
                                                                 find: .doubleQuote,
                                                                 shouldUnescape: &shouldUnescape)

                                jsonAttribute.shouldUnescape = shouldUnescape

                                appendElement(key, attributeAsHitch(nextCurrentIdx))

                                jsonAttribute.clear()

                                nextCurrentIdx += 1
                            } else if nextChar == .openBracket || nextChar == .openBrace {
                                // our value is an array or an object; we will process it next time through the main loop
                            } else if nextCurrentIdx < json.count - 3 &&
                                        nextChar == .n &&
                                        raw[nextCurrentIdx+1] == .u &&
                                        raw[nextCurrentIdx+2] == .l &&
                                        raw[nextCurrentIdx+3] == .l {
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
                                        raw[nextCurrentIdx+1] == .a &&
                                        raw[nextCurrentIdx+2] == .l &&
                                        raw[nextCurrentIdx+3] == .s &&
                                        raw[nextCurrentIdx+4] == .e {
                                        jsonAttribute.type = .booleanFalse
                                        nextCurrentIdx += 5
                                        break
                                    } else if nextChar == .t &&
                                        nextCurrentIdx < json.count - 3 &&
                                        raw[nextCurrentIdx+1] == .r &&
                                        raw[nextCurrentIdx+2] == .u &&
                                        raw[nextCurrentIdx+3] == .e {
                                        jsonAttribute.type = .booleanTrue
                                        nextCurrentIdx += 4
                                        break
                                    } else if nextChar == .dot {
                                        jsonAttribute.type = .double
                                    }
                                    nextCurrentIdx += 1
                                    nextChar = raw[nextCurrentIdx]
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
                        nextCurrentIdx = strskip(json: json, offset: currentIdx, .space, .tab, .newLine, .carriageReturn)

                        // advance forward until we find the start of the next thing
                        var nextChar = raw[nextCurrentIdx]
                        if nextChar == .forwardSlash {
                            // our value is a regex
                            jsonAttribute.type = .regex
                            jsonAttribute.valueIdx = nextCurrentIdx + 1

                            nextCurrentIdx = strstrRegex(json: json,
                                                         offset: jsonAttribute.valueIdx,
                                                         find: .forwardSlash)
                            
                            // consume the trailing forward slash
                            if json[nextCurrentIdx] == .forwardSlash {
                                nextCurrentIdx += 1
                            }
                            
                            // handle regex flags
                            let flags: HalfHitch = "igm"
                            while flags.contains(json[nextCurrentIdx]) {
                                nextCurrentIdx += 1
                            }

                            appendElement(nil, attributeAsRegex(nextCurrentIdx))

                            jsonAttribute.clear()
                        } else if nextChar == .doubleQuote {
                            // our value is a string
                            jsonAttribute.type = .string
                            jsonAttribute.valueIdx = nextCurrentIdx + 1

                            var shouldUnescape = false
                            nextCurrentIdx = strstrNoEscaped(json: json,
                                                             offset: jsonAttribute.valueIdx,
                                                             find: .doubleQuote,
                                                             shouldUnescape: &shouldUnescape)

                            jsonAttribute.shouldUnescape = shouldUnescape

                            appendElement(nil, attributeAsHitch(nextCurrentIdx))

                            jsonAttribute.clear()

                            nextCurrentIdx += 1
                        } else if nextChar == .openBrace || nextChar == .openBracket {
                            // our value is an array or an object; we will process it next time through the main loop
                            nextCurrentIdx = nextCurrentIdx - 1
                        } else if nextCurrentIdx < json.count - 3 &&
                                    nextChar == .n &&
                                    raw[nextCurrentIdx+1] == .u &&
                                    raw[nextCurrentIdx+2] == .l &&
                                    raw[nextCurrentIdx+3] == .l {
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
                                    raw[nextCurrentIdx+1] == .a &&
                                    raw[nextCurrentIdx+2] == .l &&
                                    raw[nextCurrentIdx+3] == .s &&
                                    raw[nextCurrentIdx+4] == .e {
                                    jsonAttribute.type = .booleanFalse
                                    nextCurrentIdx += 5
                                    break
                                } else if nextChar == .t &&
                                    nextCurrentIdx < json.count - 3 &&
                                    raw[nextCurrentIdx+1] == .r &&
                                    raw[nextCurrentIdx+2] == .u &&
                                    raw[nextCurrentIdx+3] == .e {
                                    jsonAttribute.type = .booleanTrue
                                    nextCurrentIdx += 4
                                    break
                                } else if nextChar == .dot {
                                    jsonAttribute.type = .double
                                }
                                nextCurrentIdx += 1
                                nextChar = raw[nextCurrentIdx]
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
                        }
                    }

                    currentIdx = nextCurrentIdx
                }
            }

            while elementStack.count > 0 {
                jsonElement = parseEndElement()
            }
            
            return rootElement
        }
    }
}
