import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTestsPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Volumes/Storage/large.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
    }
    
    func test_correctness() {
        
        let json0 = try! JSONSerialization.jsonObject(with: largeData, options: [.fragmentsAllowed])
        let jsonData0 = try! JSONSerialization.data(withJSONObject: json0, options: [.fragmentsAllowed])
        guard let jsonString0 = String(data: jsonData0, encoding: .utf8) else { return XCTFail() }
        
        largeData.parsed { results in
            let json1 = results!
            let jsonString1 = json1.description
            
            if jsonString0 != jsonString1 {
                try! jsonString1.write(toFile: "/tmp/spanker_failed.json", atomically: true, encoding: .utf8)
                XCTFail("json does not match ( \(jsonString0.count) bytes != \(jsonString1.count) bytes )")
            }
        }
    }
    
    func test_baseline() {
        measure {
            try! JSONSerialization.jsonObject(with: largeData, options: [.allowFragments])
        }
    }
    
    func test_large_load() {
        measure {
            largeData.parsed { results in }
        }
    }
    
}
