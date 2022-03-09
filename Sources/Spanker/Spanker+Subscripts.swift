import Foundation
import Hitch

public extension JsonElement {

    // MARK: - JsonElement
    @inlinable @inline(__always)
    subscript (index: Int) -> JsonElement? {
        get {
            guard internalType == .array else { return nil }

            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index]
        }
    }

    @inlinable @inline(__always)
    subscript (element index: Int) -> JsonElement? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> JsonElement? {
        get {
            guard internalType == .dictionary else { return nil }

            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index]
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    subscript (element key: HalfHitch) -> JsonElement? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> JsonElement? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (element key: Hitch) -> JsonElement? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> JsonElement? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (element key: String) -> JsonElement? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    // MARK: - HalfHitch
    @inlinable @inline(__always)
    subscript (index: Int) -> HalfHitch? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].halfHitchValue
        }
    }

    @inlinable @inline(__always)
    subscript (halfHitch index: Int) -> HalfHitch? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> HalfHitch? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].halfHitchValue
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    subscript (halfhitch key: HalfHitch) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> HalfHitch? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (halfHitch key: Hitch) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> HalfHitch? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (halfHitch key: String) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    // MARK: - Hitch
    @inlinable @inline(__always)
    subscript (index: Int) -> Hitch? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].hitchValue
        }
    }

    @inlinable @inline(__always)
    subscript (hitch index: Int) -> Hitch? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> Hitch? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].hitchValue
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    subscript (hitch key: HalfHitch) -> Hitch? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> Hitch? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (hitch key: Hitch) -> Hitch? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> Hitch? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (hitch key: String) -> Hitch? {
        get {
            return self[key]
        }
    }

    // MARK: - String
    @inlinable @inline(__always)
    subscript (index: Int) -> String? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].stringValue
        }
    }

    @inlinable @inline(__always)
    subscript (string index: Int) -> String? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> String? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].stringValue
            }
            return ""
        }
    }

    @inlinable @inline(__always)
    subscript (string key: HalfHitch) -> String? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> String? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (string key: Hitch) -> String? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> String? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (string key: String) -> String? {
        get {
            return self[key]
        }
    }

    // MARK: - Int
    @inlinable @inline(__always)
    subscript (index: Int) -> Int? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].intValue
        }
    }

    @inlinable @inline(__always)
    subscript (int index: Int) -> Int? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> Int? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].intValue
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    subscript (int key: HalfHitch) -> Int? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> Int? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (int key: Hitch) -> Int? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> Int? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (int key: String) -> Int? {
        get {
            return self[key]
        }
    }

    // MARK: - Double
    @inlinable @inline(__always)
    subscript (index: Int) -> Double? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].doubleValue
        }
    }

    @inlinable @inline(__always)
    subscript (double index: Int) -> Double? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> Double? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].doubleValue
            }
            return nil
        }
    }

    @inlinable @inline(__always)
    subscript (double key: HalfHitch) -> Double? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> Double? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (double key: Hitch) -> Double? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> Double? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (double key: String) -> Double? {
        get {
            return self[key]
        }
    }

    // MARK: - Bool
    @inlinable @inline(__always)
    subscript (index: Int) -> Bool? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].boolValue
        }
    }

    @inlinable @inline(__always)
    subscript (bool index: Int) -> Bool? {
        get {
            return self[index]
        }
    }

    @inlinable @inline(__always)
    subscript (key: HalfHitch) -> Bool? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].boolValue
            }
            return false
        }
    }

    @inlinable @inline(__always)
    subscript (bool key: HalfHitch) -> Bool? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: Hitch) -> Bool? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable @inline(__always)
    subscript (bool key: Hitch) -> Bool? {
        get {
            return self[key]
        }
    }

    @inlinable @inline(__always)
    subscript (key: String) -> Bool? {
        get {
            return self[HalfHitch(string: key)]
        }
    }

    @inlinable @inline(__always)
    subscript (bool key: String) -> Bool? {
        get {
            return self[key]
        }
    }
}
