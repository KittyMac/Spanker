import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTestsMemoryPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Volumes/Storage/large.minified.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
    }
    
    func test_baseline() {
        measure(metrics: [XCTMemoryMetric()], options: .default) {
            if let obj = try? JSONSerialization.jsonObject(with: largeData, options: [.allowFragments]),
               let jsonArray = obj as? [Any] {
                XCTAssertEqual(jsonArray.count, 11351)
            }
        }
    }
    
    func test_large_load() {
        measure(metrics: [XCTMemoryMetric()], options: .default) {
            largeData.parsed { results in
                XCTAssertEqual(results?.count, 11351)
            }
        }
    }
    
}
