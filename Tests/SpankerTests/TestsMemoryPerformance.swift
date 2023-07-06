import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTestsMemoryPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Users/rjbowli/Development/data/large.minified.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
    }
    
    func test_github1() {
        largeData.parsed { result in }
    }
    
}
