import Foundation
import Hitch

@inlinable @inline(__always)
internal func strskip(json: HalfHitch, offset: Int, _ params: UInt8...) -> Int {
    var idx = offset
    for char in json.stride(from: offset, to: json.count) {
        guard char != 0 else { break }
        guard params.contains(char) else { break }
        idx += 1
    }
    return idx
}

@inlinable @inline(__always)
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
            return parsed(data: hitch.dataNoCopy(), callback)
        }

        @usableFromInline
        internal static func parsed<T>(string: String, _ callback: (JsonElement?) -> T?) -> T? {
            return parsed(data: string.data(using: .utf8) ?? Data(), callback)
        }

        @usableFromInline
        internal static func parsed<T>(data: Data, _ callback: (JsonElement?) -> T?) -> T? {
            var currentIdx = 0
            var char: UInt8 = 0

            var elementStack: [JsonElement] = []

            var jsonAttribute = ParseValue()
            var rootElement: JsonElement?
            var jsonElement: JsonElement?

            return HalfHitch.using(data: data) { json in

                let parseEndElement: () -> JsonElement? = {
                    guard elementStack.count > 0 else { return nil }
                    let myElement = elementStack.removeLast()

                    if elementStack.count == 0 {
                        rootElement = myElement
                    }

                    return elementStack.last
                }

                let attributeAsHitch: (Int) -> JsonElement = { endIdx in
                    guard jsonAttribute.valueIdx < endIdx else { return JsonElement.emptyString }
                    var valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx, to: endIdx)
                    if jsonAttribute.shouldUnescape {
                        valueString.unescape()
                    }
                    return JsonElement(string: valueString)
                }

                let attributeAsInt: (Int) -> JsonElement = { endIdx in
                    if jsonAttribute.valueIdx + 1 == endIdx {
                        let char = json[jsonAttribute.valueIdx]
                        if char == UInt8.zero {
                            return JsonElement.intZero
                        } else if char == UInt8.one {
                            return JsonElement.intOne
                        } else if char == UInt8.two {
                            return JsonElement.intTwo
                        } else if char == UInt8.three {
                            return JsonElement.intThree
                        } else if char == UInt8.four {
                            return JsonElement.intFour
                        } else if char == UInt8.five {
                            return JsonElement.intFive
                        } else if char == UInt8.six {
                            return JsonElement.intSix
                        } else if char == UInt8.seven {
                            return JsonElement.intSeven
                        } else if char == UInt8.eight {
                            return JsonElement.intEight
                        } else if char == UInt8.nine {
                            return JsonElement.intNine
                        }
                    }
                    let valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx, to: endIdx)
                    guard let value = valueString.toInt() else { return JsonElement.null }
                    return JsonElement(int: value)
                }

                let attributeAsDouble: (Int) -> JsonElement = { endIdx in
                    if jsonAttribute.valueIdx + 3 == endIdx {
                        if json[jsonAttribute.valueIdx+1] == UInt8.dot &&
                            json[jsonAttribute.valueIdx+2] == UInt8.zero {
                            let char = json[jsonAttribute.valueIdx]
                            if char == UInt8.zero {
                                return JsonElement.doubleZero
                            } else if char == UInt8.one {
                                return JsonElement.doubleOne
                            } else if char == UInt8.two {
                                return JsonElement.doubleTwo
                            } else if char == UInt8.three {
                                return JsonElement.doubleThree
                            } else if char == UInt8.four {
                                return JsonElement.doubleFour
                            } else if char == UInt8.five {
                                return JsonElement.doubleFive
                            } else if char == UInt8.six {
                                return JsonElement.doubleSix
                            } else if char == UInt8.seven {
                                return JsonElement.doubleSeven
                            } else if char == UInt8.eight {
                                return JsonElement.doubleEight
                            } else if char == UInt8.nine {
                                return JsonElement.doubleNine
                            }
                        }
                    }
                    let valueString = HalfHitch(source: json, from: jsonAttribute.valueIdx, to: endIdx)
                    guard let value = valueString.toDouble() else { return JsonElement.null }
                    return JsonElement(double: value)
                }

                let attributeName: () -> HalfHitch? = {
                    guard jsonAttribute.nameIdx > 0 else { return nil }
                    var name = HalfHitch(source: json, from: jsonAttribute.nameIdx, to: jsonAttribute.endNameIdx)
                    if jsonAttribute.shouldUnescape {
                        name.unescape()
                    }
                    return name
                }

                let appendElement: (HalfHitch?, JsonElement) -> Void = { key, value in
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
                                        jsonElement.append(key: name, value: nextElement)
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
                                processElement(JsonElement.emptyDictionary)
                            } else if nextChar == .closeBrace {
                                processElement(JsonElement.emptyArray)
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
                                    key.unescape()
                                }

                                // advance forward until we find the start of the next thing
                                var nextChar = raw[nextCurrentIdx]
                                if nextChar == .doubleQuote {
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

                                    appendElement(key, JsonElement.null)

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
                                        appendElement(key, JsonElement.true)
                                    } else if jsonAttribute.type == .booleanFalse {
                                        appendElement(key, JsonElement.false)
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
                            if nextChar == .doubleQuote {
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

                                appendElement(nil, JsonElement.null)

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
                                    appendElement(nil, JsonElement.true)
                                } else if jsonAttribute.type == .booleanFalse {
                                    appendElement(nil, JsonElement.false)
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

                return callback(rootElement)
            }

        }

    }
}
