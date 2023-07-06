import Foundation
import Hitch

public extension JsonElement {

    // MARK: - JsonElement
    @inlinable
    subscript (index: Int) -> JsonElement? {
        get {
            guard internalType == .array else { return nil }

            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index]
        }
    }

    @inlinable
    subscript (element index: Int) -> JsonElement? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> JsonElement? {
        get {
            guard internalType == .dictionary else { return nil }

            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index]
            }
            return nil
        }
    }

    @inlinable
    subscript (element key: HalfHitch) -> JsonElement? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> JsonElement? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (element key: Hitch) -> JsonElement? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (key: String) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (element key: String) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (element key: StaticString) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    // MARK: - HalfHitch
    @inlinable
    subscript (index: Int) -> HalfHitch? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].halfHitchValue
        }
    }

    @inlinable
    subscript (halfHitch index: Int) -> HalfHitch? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> HalfHitch? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].halfHitchValue
            }
            return nil
        }
    }

    @inlinable
    subscript (halfhitch key: HalfHitch) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> HalfHitch? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (halfHitch key: Hitch) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> HalfHitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> HalfHitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (halfHitch key: String) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    // MARK: - Hitch
    @inlinable
    subscript (index: Int) -> Hitch? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].hitchValue
        }
    }

    @inlinable
    subscript (hitch index: Int) -> Hitch? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> Hitch? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].hitchValue
            }
            return nil
        }
    }

    @inlinable
    subscript (hitch key: HalfHitch) -> Hitch? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> Hitch? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (hitch key: Hitch) -> Hitch? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> Hitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> Hitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (hitch key: String) -> Hitch? {
        get {
            return self[key]
        }
    }

    // MARK: - String
    @inlinable
    subscript (index: Int) -> String? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].stringValue
        }
    }

    @inlinable
    subscript (string index: Int) -> String? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> String? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].stringValue
            }
            return nil
        }
    }

    @inlinable
    subscript (string key: HalfHitch) -> String? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> String? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (string key: Hitch) -> String? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> String? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> String? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (string key: String) -> String? {
        get {
            return self[key]
        }
    }

    // MARK: - Int
    @inlinable
    subscript (index: Int) -> Int? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].intValue
        }
    }

    @inlinable
    subscript (int index: Int) -> Int? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> Int? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].intValue
            }
            return nil
        }
    }

    @inlinable
    subscript (int key: HalfHitch) -> Int? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> Int? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (int key: Hitch) -> Int? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> Int? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> Int? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (int key: String) -> Int? {
        get {
            return self[key]
        }
    }

    // MARK: - Double
    @inlinable
    subscript (index: Int) -> Double? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            if let value = valueArray[index].doubleValue { return value }
            if let value = valueArray[index].intValue { return Double(value) }
            return nil
        }
    }

    @inlinable
    subscript (double index: Int) -> Double? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> Double? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                if let value = valueArray[index].doubleValue { return value }
                if let value = valueArray[index].intValue { return Double(value) }
            }
            return nil
        }
    }

    @inlinable
    subscript (double key: HalfHitch) -> Double? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> Double? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (double key: Hitch) -> Double? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> Double? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> Double? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (double key: String) -> Double? {
        get {
            return self[key]
        }
    }
    
    // MARK: - Float
    @inlinable
    subscript (index: Int) -> Float? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            if let value = valueArray[index].doubleValue { return Float(value) }
            if let value = valueArray[index].intValue { return Float(value) }
            return nil
        }
    }

    @inlinable
    subscript (float index: Int) -> Float? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> Float? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                if let value = valueArray[index].doubleValue { return Float(value) }
                if let value = valueArray[index].intValue { return Float(value) }
            }
            return nil
        }
    }

    @inlinable
    subscript (float key: HalfHitch) -> Float? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> Float? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (float key: Hitch) -> Float? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> Float? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> Float? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (float key: String) -> Float? {
        get {
            return self[key]
        }
    }

    // MARK: - Bool
    @inlinable
    subscript (index: Int) -> Bool? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].boolValue
        }
    }

    @inlinable
    subscript (bool index: Int) -> Bool? {
        get {
            return self[index]
        }
    }

    @inlinable
    subscript (key: HalfHitch) -> Bool? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].boolValue
            }
            return false
        }
    }

    @inlinable
    subscript (bool key: HalfHitch) -> Bool? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: Hitch) -> Bool? {
        get {
            return self[key.halfhitch()]
        }
    }

    @inlinable
    subscript (bool key: Hitch) -> Bool? {
        get {
            return self[key]
        }
    }

    @inlinable
    subscript (key: String) -> Bool? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    
    @inlinable
    subscript (key: StaticString) -> Bool? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    @inlinable
    subscript (bool key: String) -> Bool? {
        get {
            return self[key]
        }
    }
}
