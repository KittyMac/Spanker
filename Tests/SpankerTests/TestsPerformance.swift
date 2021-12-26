import XCTest
import class Foundation.Bundle

import Spanker

class SpankerTestsPerformance: TestsBase {
    
    var largeData: Data = Data()
    
    override func setUp() {
        let largeDataPath = "/Volumes/Storage/large.minified.json"
        largeData = try! Data(contentsOf: URL(fileURLWithPath: largeDataPath))
    }
    
    func test_baseline() {
        measure {
            if let obj = try? JSONSerialization.jsonObject(with: largeData, options: [.allowFragments]),
               let jsonArray = obj as? [Any] {
                print(jsonArray.count)
            }
        }
    }
    
    func test_large_load() {
        measure {
            largeData.parsed { results in
                if let results = results {
                    print(results.count)
                }
            }
        }
    }
    
}
