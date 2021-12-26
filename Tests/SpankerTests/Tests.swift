import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTests: TestsBase {
    
    func test_empty_array() {
        let json = #"[]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_empty_object() {
        let json = #"{}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_numbers0() {
        let json = #"[0,1,2,3]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_numbers1() {
        let json = #"[0.5,1.2,2.7,3.7556367]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_array_strings0() {
            let json = #"["A","B","C"]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
        }
    
    func test_object_simple0() {
        let json = #"{"foo":"bar"}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple1() {
        let json = #"{"foo":{"bar":"baz"}}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple2() {
        let json = "{\"int-max-property\":\(UINT32_MAX),\"long-max-property\":\(LLONG_MAX)}"
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple3() {
        let json = #"[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","display-price":8.95},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","display-price":12.99},{"category":"fiction","author":"Herman Melville","title":"Moby Dick","isbn":"0-553-21311-3","display-price":8.99},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","display-price":22.99}]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple4() {
            let json = #"{"store":{"book":[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","price":8.95,"address":{"street":"fleet street","city":"London"}},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","price":12.9,"address":{"street":"Baker street","city":"London"}},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","price":22.99,"address":{"street":"Svea gatan","city":"Stockholm"}}],"bicycle":{"color":"red","price":19.95,"address":{"street":"Söder gatan","city":"Stockholm"},"items":[["A","B","C"],1,2,3,4,5]}}}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
        }
    
    func test_boolean() {
        let jsons = [
            #"true"#,
            #"false"#,
            #"[true]"#,
            #"[false]"#,
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
    func test_int() {
        let jsons = [
            #"0"#,
            #"1245678"#,
            #"-1245678"#,
            #"[0]"#,
            #"[1245678]"#,
            #"[-1245678]"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
    func test_double() {
        let jsons = [
            #"0.0"#,
            #"0"#,
            #"1245678.2642348"#,
            #"-1245678.2397824"#,
            #"[0.0]"#,
            #"[0]"#,
            #"[1245678.2642348]"#,
            #"[-1245678.2397824]"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
    func test_string() {
        let json = #""hello world""#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_compliance0() {
        jsonDocument.parsed { result in
            XCTAssertEqual(jsonDocument, result?.description)
        }
    }
    
    func test_many() {
        let jsons = [
            jsonDocument,
            jsonTextSeries,
            jsonNumberSeries,
            #"{"store":{"book":[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","price":8.95,"address":{"street":"fleet street","city":"London"}},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","price":12.9,"address":{"street":"Baker street","city":"London"}},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","price":22.99,"address":{"street":"Svea gatan","city":"Stockholm"}}],"bicycle":{"color":"red","price":19.95,"address":{"street":"Söder gatan","city":"Stockholm"},"items":[["A","B","C"],1,2,3,4,5]}}}"#,
            #"{"data":{"people":[{"name":"Rocco","age":42},{"name":"John","age":12},{"name":"Elizabeth","age":35},{"name":"Victoria","age":85}]}}"#,
            #"{"access_token":"aex-0u-7Yq09sBls123456789","expires_in":2678400,"token_type":"Bearer","scope":"identity","refresh_token":"CayptzsmZ_MejrKgNtAF8ka36123456789","version":"0.0.1"}"#,
            #"{"data":{"attributes":{"about":null,"created":"2021-12-19T18:06:51.000+00:00","first_name":"John","full_name":"John Doe","image_url":"https://www.example.com/image.png","last_name":"Doe","thumb_url":"https://www.example.com/image.png","url":"https://www.example.com/user?u=234576235","vanity":null},"id":"234576235","type":"user"},"links":{"self":"https://www.example.com/api/oauth2/v2/user/234576235"}}"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json, result?.description)
            }
        }
    }
    
}
