import Foundation
import Hitch

public extension JsonElement {

    // MARK: - JsonElement

    subscript (index: Int) -> JsonElement? {
        get {
            guard internalType == .array else { return nil }

            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index]
        }
    }


    subscript (element index: Int) -> JsonElement? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> JsonElement? {
        get {
            guard internalType == .dictionary else { return nil }

            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index]
            }
            return nil
        }
    }


    subscript (element key: HalfHitch) -> JsonElement? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> JsonElement? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (element key: Hitch) -> JsonElement? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (key: String) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (element key: String) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (element key: StaticString) -> JsonElement? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }

    // MARK: - HalfHitch

    subscript (index: Int) -> HalfHitch? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].halfHitchValue
        }
    }


    subscript (halfHitch index: Int) -> HalfHitch? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> HalfHitch? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].halfHitchValue
            }
            return nil
        }
    }


    subscript (halfhitch key: HalfHitch) -> HalfHitch? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> HalfHitch? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (halfHitch key: Hitch) -> HalfHitch? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> HalfHitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> HalfHitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (halfHitch key: String) -> HalfHitch? {
        get {
            return self[key]
        }
    }

    // MARK: - Hitch

    subscript (index: Int) -> Hitch? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].hitchValue
        }
    }


    subscript (hitch index: Int) -> Hitch? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> Hitch? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].hitchValue
            }
            return nil
        }
    }


    subscript (hitch key: HalfHitch) -> Hitch? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> Hitch? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (hitch key: Hitch) -> Hitch? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> Hitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> Hitch? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (hitch key: String) -> Hitch? {
        get {
            return self[key]
        }
    }

    // MARK: - String

    subscript (index: Int) -> String? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].stringValue
        }
    }


    subscript (string index: Int) -> String? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> String? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].stringValue
            }
            return nil
        }
    }


    subscript (string key: HalfHitch) -> String? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> String? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (string key: Hitch) -> String? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> String? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> String? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (string key: String) -> String? {
        get {
            return self[key]
        }
    }

    // MARK: - Int

    subscript (index: Int) -> Int? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].intValue
        }
    }


    subscript (int index: Int) -> Int? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> Int? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].intValue
            }
            return nil
        }
    }


    subscript (int key: HalfHitch) -> Int? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> Int? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (int key: Hitch) -> Int? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> Int? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> Int? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (int key: String) -> Int? {
        get {
            return self[key]
        }
    }

    // MARK: - Double

    subscript (index: Int) -> Double? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            if let value = valueArray[index].doubleValue { return value }
            if let value = valueArray[index].intValue { return Double(value) }
            return nil
        }
    }


    subscript (double index: Int) -> Double? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> Double? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                if let value = valueArray[index].doubleValue { return value }
                if let value = valueArray[index].intValue { return Double(value) }
            }
            return nil
        }
    }


    subscript (double key: HalfHitch) -> Double? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> Double? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (double key: Hitch) -> Double? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> Double? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> Double? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (double key: String) -> Double? {
        get {
            return self[key]
        }
    }
    
    // MARK: - Float

    subscript (index: Int) -> Float? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            if let value = valueArray[index].doubleValue { return Float(value) }
            if let value = valueArray[index].intValue { return Float(value) }
            return nil
        }
    }


    subscript (float index: Int) -> Float? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> Float? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                if let value = valueArray[index].doubleValue { return Float(value) }
                if let value = valueArray[index].intValue { return Float(value) }
            }
            return nil
        }
    }


    subscript (float key: HalfHitch) -> Float? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> Float? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (float key: Hitch) -> Float? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> Float? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> Float? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (float key: String) -> Float? {
        get {
            return self[key]
        }
    }

    // MARK: - Bool

    subscript (index: Int) -> Bool? {
        get {
            guard index >= 0 && index < valueArray.count else { return nil }
            return valueArray[index].boolValue
        }
    }


    subscript (bool index: Int) -> Bool? {
        get {
            return self[index]
        }
    }


    subscript (key: HalfHitch) -> Bool? {
        get {
            if let index = keyArray.firstIndex(of: key) {
                return valueArray[index].boolValue
            }
            return false
        }
    }


    subscript (bool key: HalfHitch) -> Bool? {
        get {
            return self[key]
        }
    }


    subscript (key: Hitch) -> Bool? {
        get {
            return self[key.halfhitch()]
        }
    }


    subscript (bool key: Hitch) -> Bool? {
        get {
            return self[key]
        }
    }


    subscript (key: String) -> Bool? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }
    

    subscript (key: StaticString) -> Bool? {
        get {
            return self[HalfHitch(hashOnly: key)]
        }
    }


    subscript (bool key: String) -> Bool? {
        get {
            return self[key]
        }
    }
}
