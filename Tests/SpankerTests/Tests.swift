import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTests: TestsBase {
    
    func test_empty_array() {
        let json = #"[]"#
        XCTAssertEqual(json, Spanker.parse(string: json)?.description)
    }
    
    func test_empty_object() {
        let json = #"{}"#
        XCTAssertEqual(json, Spanker.parse(string: json)?.description)
    }
    
    func test_number_array() {
        let json = #"[0,1,2,3]"#
        XCTAssertEqual(json, Spanker.parse(string: json)?.description)
    }
    
    func test_simple_object() {
        let json = #"{"foo":"bar"}"#
        XCTAssertEqual(json, Spanker.parse(string: json)?.description)
    }
    
    func test_simple2_object() {
        let json = #"{"foo":{"bar":"baz"}}"#
        XCTAssertEqual(json, Spanker.parse(string: json)?.description)
    }
    
}
