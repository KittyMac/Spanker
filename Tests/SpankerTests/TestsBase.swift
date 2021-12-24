import XCTest
import class Foundation.Bundle

import Spanker

func XCTAssertEqualAny(_ inFirst: Any?, _ inSecond: Any?) {
    guard let first = inFirst else { return XCTAssertTrue(inFirst == nil && inSecond == nil, "one of the arguments is nil") }
    guard let second = inSecond else { return XCTAssertTrue(false, "second argument is nil") }
    
    if let first = first as? [String],
       let second = second as? [String] {
        XCTAssertEqual(first.sorted().joined(),
                       second.sorted().joined())
        return
    }
    if let first = first as? String,
       let second = second as? String {
        XCTAssertEqual(first, second)
        return
    }
    if let first = first as? Int,
       let second = second as? Int {
        XCTAssertEqual(first, second)
        return
    }
    if let first = first as? Double,
       let second = second as? Double {
        XCTAssertEqual(first, second)
        return
    }
    
    guard first as? JsonDictionary != nil || first as? JsonArray != nil else { return XCTAssertTrue(false) }
    guard second as? JsonDictionary != nil || second as? JsonArray != nil else { return XCTAssertTrue(false) }
    
    guard let firstData = try? JSONSerialization.data(withJSONObject: first, options: [.sortedKeys]) else { XCTAssertTrue(false); return }
    guard let secondData = try? JSONSerialization.data(withJSONObject: second, options: [.sortedKeys]) else { XCTAssertTrue(false); return }
    XCTAssertEqual(String(data: firstData, encoding: .utf8),
                   String(data: secondData, encoding: .utf8))
}


public class TestsBase: XCTestCase {
    
}
