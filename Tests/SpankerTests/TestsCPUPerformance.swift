import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTestsCPUPerformance: TestsBase {
    
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Users/rjbowli/Development/data/large.minified.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: largeDataPath)) {
            largeData = data
        } else {
            print("warning: large.minified.json missing")
        }
    }
    
    func test_baseline() {
        // 0.187
        measure {
            if let obj = try? JSONSerialization.jsonObject(with: largeData, options: [.allowFragments]),
               let jsonArray = obj as? [Any] {
                XCTAssertEqual(jsonArray.count, 11351)
            }
        }
    }
    
    func test_large_load() {
        
        // 0.387
        // -- inlinable always -- 0.367
        // -- inlinable -- 0.368
        measure {
            largeData.parsed { results in
                XCTAssertEqual(results?.count, 11351)
            }
        }
    }
    
}
