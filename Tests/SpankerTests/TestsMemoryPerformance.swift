import XCTest
import class Foundation.Bundle

import SpankerKit

class SpankerTestsMemoryPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Volumes/Storage/large.minified.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
    }
    
    func test_github1() {
        largeData.parsed { result in }
    }
    
}
