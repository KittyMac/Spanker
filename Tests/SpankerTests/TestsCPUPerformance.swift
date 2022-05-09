import XCTest
import class Foundation.Bundle

import SpankerKit

class SpankerTestsCPUPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Volumes/Storage/large.minified.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
    }
    
    func test_baseline() {
        // 0.394
        // 0.395
        // 0.377
        // 0.407
        // 0.416
        measure {
            if let obj = try? JSONSerialization.jsonObject(with: largeData, options: [.allowFragments]),
               let jsonArray = obj as? [Any] {
                XCTAssertEqual(jsonArray.count, 11351)
            }
        }
    }
    
    func test_large_load() {
        // 0.594
        // 0.588
        // 0.625
        // 0.684
        // 0.762
        // 0.791
        measure {
            largeData.parsed { results in
                XCTAssertEqual(results?.count, 11351)
            }
        }
    }
    
}
