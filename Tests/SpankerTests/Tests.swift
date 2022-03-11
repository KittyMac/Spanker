import XCTest
import class Foundation.Bundle

import Spanker
import Hitch

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
    
    func test_array_numbersAt() {
        let json = #"[0,1,2,3]"#
        json.parsed { result in
            guard let result = result else { XCTFail(); return }
            XCTAssertEqual(result[1], 1)
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
    
    func test_object_simpleAt() {
        let json = #"{"foo":{"bar":"baz"}}"#
        json.parsed { result in
            guard let result = result else { XCTFail(); return }
            XCTAssertEqual(JsonElement(unknown: ["bar": "baz"]), result[element: "foo"])
        }
    }
    
    func test_array_objects_simple1() {
        let json = #"[{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}},{"foo":{"bar":"baz"}}]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_containsAll() {
        let json = #"{"foo0":{"bar":"baz"},"foo1":{"bar":"baz"},"foo2":{"bar":"baz"},"foo3":{"bar":"baz"},"foo4":{"bar":"baz"},"foo5":{"bar":"baz"}"#
        json.parsed { result in
            guard let result = result else { XCTFail(); return }
            guard result.type == .dictionary else { XCTFail(); return }
            
            let propertiesSuccess: [Hitch] = [
                "foo0",
                "foo1",
                "foo2",
            ]
            let propertiesFail: [Hitch] = [
                "foo0",
                "fooA",
                "foo2",
            ]
            
            XCTAssertTrue(result.containsAll(keys: propertiesSuccess))
            XCTAssertFalse(result.containsAll(keys: propertiesFail))
            
            let propertiesSuccess2 = propertiesSuccess.map { $0.halfhitch() }
            let propertiesFail2 = propertiesFail.map { $0.halfhitch() }
            
            XCTAssertTrue(result.containsAll(keys: propertiesSuccess2))
            XCTAssertFalse(result.containsAll(keys: propertiesFail2))
        }
    }
    
    func test_object_simple2() {
        let json = "{\"int-max-property\":\(UINT32_MAX),\"long-max-property\":\(INT64_MAX)}"
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
    
    func test_object_simple5() {
        let json = #"["{}[]","{}[]","{}[]","{}[]"]"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_object_simple6() {
        let json = #"{"key0":"{}[]","key1":"{}[]","key2":"{}[]","key3":"{}[]"}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_unknown() {
        XCTAssertEqual(JsonElement(unknown: [
            nil,
            NSNull(),
            true,
            false,
            1,
            1.0,
            "hello",
            [1,2,3],
            ["a":"b"]
        ]).toHitch(), #"[null,null,true,false,1,1.0,"hello",[1,2,3],{"a":"b"}]"#)
    }
    
    func test_values() {
        let element = JsonElement(unknown: [:])
        element.set(key: "a", value: 1)
        element.set(key: "b", value: 2)
        element.set(key: "c", value: 3)
        element.set(key: "d", value: 4)
        XCTAssertEqual(element.values.toHitch(), #"[1,2,3,4]"#)
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
    
    func test_test0() {
        let json = #"{"foo":[1,2],"bar":{"a":true}}"#
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_jsonElementEquality() {
        let jsonTrue = #"[1, 1, 0.1, 0.1, true, true, "hello", "hello", [1,2,3], [1,2,3], {"foo":"bar"}, {"foo":"bar"}]"#
        jsonTrue.parsed { result in
            guard let result = result else { XCTFail(); return }
            
            for idx in 0..<result.count {
                if idx % 2 == 0 {
                    XCTAssertEqual(result[element: idx], result[element: idx+1])
                }
            }
        }
        
        let jsonFalse = #"[1, 2, 0.1, 0.2, true, false, "hello", "world", [1,2,3], [4,5,6], {"foo":"bar"}, {"foo":"baz"}]"#
        jsonFalse.parsed { result in
            guard let result = result else { XCTFail(); return }
            
            for idx in 0..<result.count {
                if idx % 2 == 0 {
                    XCTAssertNotEqual(result[element: idx], result[element: idx+1])
                }
            }
        }
    }
        
    func test_escaped_string() {
        let json = #""u\u0308""#
        
        let result = try! JSONSerialization.jsonObject(with: json.data(using: .utf8)!, options: [.allowFragments])
        XCTAssertEqual("ü", result as! String)
        
        json.parsed { result in
            XCTAssertEqual("ü", result?.reify() as! String)
            XCTAssertEqual(#""ü""#, result?.description)
        }
    }
    
    func test_escaped_strings() {
        let jsons = [
            #"{"logs":[{"message":"\"it\"","id":2}]}"#,
            #"{"logs":[{"message":"it\\\r\n\\","id":2}]}"#,
            #"{"u\u0308":42}"#
        ]
        for json in jsons {
            json.parsed { result in
                XCTAssertEqual(json.replacingOccurrences(of: "u\\u0308", with: "ü"), result?.description)
            }
        }
    }
    
    func test_github0() {
        let json = ##"[{"id":"2489651045","type":"CreateEvent","actor":{"id":665991,"login":"petroav","gravatar_id":"","url":"https://api.github.com/users/petroav","avatar_url":"https://avatars.githubusercontent.com/u/665991?"},"repo":{"id":28688495,"name":"petroav/6.828","url":"https://api.github.com/repos/petroav/6.828"},"payload":{"ref":"master","ref_type":"branch","master_branch":"master","description":"Solution to homework and assignments from MIT's 6.828 (Operating Systems Engineering). Done in my spare time.","pusher_type":"user"},"public":true,"created_at":"2015-01-01T15:00:00Z"},{"id":"2489651051","type":"PushEvent","actor":{"id":3854017,"login":"rspt","gravatar_id":"","url":"https://api.github.com/users/rspt","avatar_url":"https://avatars.githubusercontent.com/u/3854017?"},"repo":{"id":28671719,"name":"rspt/rspt-theme","url":"https://api.github.com/repos/rspt/rspt-theme"},"payload":{"push_id":536863970,"size":1,"distinct_size":1,"ref":"refs/heads/master","head":"6b089eb4a43f728f0a594388092f480f2ecacfcd","before":"437c03652caa0bc4a7554b18d5c0a394c2f3d326","commits":[{"sha":"6b089eb4a43f728f0a594388092f480f2ecacfcd","author":{"email":"5c682c2d1ec4073e277f9ba9f4bdf07e5794dabe@rspt.ch","name":"rspt"},"message":"Fix main header height on mobile","distinct":true,"url":"https://api.github.com/repos/rspt/rspt-theme/commits/6b089eb4a43f728f0a594388092f480f2ecacfcd"}]},"public":true,"created_at":"2015-01-01T15:00:01Z"},{"id":"2489651053","type":"PushEvent","actor":{"id":6339799,"login":"izuzero","gravatar_id":"","url":"https://api.github.com/users/izuzero","avatar_url":"https://avatars.githubusercontent.com/u/6339799?"},"repo":{"id":28270952,"name":"izuzero/xe-module-ajaxboard","url":"https://api.github.com/repos/izuzero/xe-module-ajaxboard"},"payload":{"push_id":536863972,"size":1,"distinct_size":1,"ref":"refs/heads/develop","head":"ec819b9df4fe612bb35bf562f96810bf991f9975","before":"590433109f221a96cf19ea7a7d9a43ca333e3b3e","commits":[{"sha":"ec819b9df4fe612bb35bf562f96810bf991f9975","author":{"email":"df05f55543db3c62cf64f7438018ec37f3605d3c@gmail.com","name":"Eunsoo Lee"},"message":"#20 게시글 및 댓글 삭제 시 새로고침이 되는 문제 해결\n\n원래 의도는 새로고침이 되지 않고 확인창만으로 해결되어야 함.\n기본 게시판 대응 플러그인에서 발생한 이슈.","distinct":true,"url":"https://api.github.com/repos/izuzero/xe-module-ajaxboard/commits/ec819b9df4fe612bb35bf562f96810bf991f9975"}]},"public":true,"created_at":"2015-01-01T15:00:01Z"}]"##
        json.parsed { result in
            XCTAssertEqual(json, result?.description)
        }
    }
    
    func test_github1() {
        let jsonString = try! String(contentsOfFile: "/Volumes/Storage/large.minified.json")
        jsonString.parsed { result in
            guard let result = result else { XCTFail(); return }
            
            XCTAssertEqual(jsonString.count, result.description.count)
        }
    }
    
    func test_compliance0() {
        jsonDocument.parsed { result in
            XCTAssertEqual(jsonDocument.replacingOccurrences(of: "\\u002A", with: "*"), result?.description)
        }
    }
    
    func test_many() {
        let jsons = [
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
    
    func test_iterators() {
        let valuesJson = #"[10,1,2,3,4,5,6,7,8,9]"#
        
        valuesJson.parsed { root in
            guard let root = root else { return }
            var total = 0
            for value in root.iterValues {
                total += value.intValue ?? 0
            }
            XCTAssertEqual(total, 55)
        }
        
        let keysJson = #"{"Hello":0," ":1,"World":2}"#
        
        keysJson.parsed { root in
            guard let root = root else { return }
            let combined = Hitch()
            for key in root.iterKeys {
                combined.append(key)
            }
            XCTAssertEqual(combined, "Hello World")
        }
    }
    
    func test_element_clean0() {
        let jsonElement = JsonElement(unknown: [
            nil,
            "Hello",
            nil,
            12345,
            nil,
            "World",
            nil
        ])
        
        jsonElement.clean()
        
        XCTAssertEqual(jsonElement.description, #"["Hello",12345,"World"]"#)
    }

    func test_element_clean1() {
        let jsonElement = JsonElement(unknown: [
            "key0": nil,
            "key1": "Hello",
            "key2": nil,
            "key3": 12345,
            "key4": nil,
            "key5": "World",
            "key6": nil
        ])
        
        jsonElement.clean()
        
        XCTAssertEqual(jsonElement.count, 3)
    }
    
    func test_sortKeys() {
        let jsonA = JsonElement(unknown: [
            "a": 1,
            "b": 2,
            "c": 3,
            "d": 4,
            "child": [
                "d": 4,
                "c": 3,
                "b": 2,
                "a": 1
            ]
        ])
        
        let jsonB = JsonElement(unknown: [
            "child": [
                "d": 4,
                "c": 3,
                "b": 2,
                "a": 1
            ],
            "d": 4,
            "c": 3,
            "b": 2,
            "a": 1
        ])
        
        jsonA.sortKeys()
        jsonB.sortKeys()
        
        XCTAssertEqual(jsonA.toHitch(), jsonB.toHitch())
    }
    
    func test_sortAll() {
        let jsonA = JsonElement(unknown: [
            "array": [
                "12345",
                false,
                [0,1,2],
                [2,1,0],
                42,
                "54321"
            ],
            "a": 1,
            "b": 2,
            "c": 3,
            "d": 4,
            "child": [
                "d": 4,
                "c": 3,
                "b": 2,
                "a": 1
            ]
        ])
        
        let jsonB = JsonElement(unknown: [
            "child": [
                "d": 4,
                "c": 3,
                "b": 2,
                "a": 1
            ],
            "array": [
                [0,1,2],
                "12345",
                false,
                "54321",
                [2,1,0],
                42
            ],
            "d": 4,
            "c": 3,
            "b": 2,
            "a": 1
        ])
        
        jsonA.sortAll()
        jsonB.sortAll()
                
        XCTAssertEqual(jsonA.toHitch(), jsonB.toHitch())
    }

    
}
