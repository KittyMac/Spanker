import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTestsPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Volumes/Storage/large.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
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
