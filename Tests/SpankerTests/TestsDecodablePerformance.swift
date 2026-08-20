import XCTest
import class Foundation.Bundle

import Spanker
import Hitch

#if canImport(Darwin)
import Darwin
#endif

// Compares decoding a Codable type via Foundation's JSONDecoder against decoding
// straight from a parsed JsonElement (Spanker+Decodable).
//
// Run with `swift test -c release --filter SpankerTestsDecodablePerformance`.
// A DEBUG build tells you nothing useful here: this decoder is almost entirely
// generic protocol dispatch, which debug builds neither specialize nor
// devirtualize, while JSONDecoder ships pre-optimized inside libFoundation.
// Measured on Linux/Swift 5.10 debug, Spanker looked 6.6x slower purely from that.

let loremStatic: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

// MARK: - Fixtures

fileprivate struct PerfNested: Codable, Equatable {
    let a: Int
    let b: [Int]
    let c: String
}

fileprivate struct PerfItem: Codable, Equatable {
    let id: String
    let index: Int
    let score: Double
    let active: Bool
    let tags: [String]
    let note: String?
    let nested: PerfNested
}

fileprivate struct PerfPayload: Codable, Equatable {
    let version: Int
    let items: [PerfItem]
}

fileprivate func makePerfPayload(_ count: Int) -> Data {
    var items: [PerfItem] = []
    items.reserveCapacity(count)
    for idx in 0..<count {
        let tags: [String] = [
            "alpha",
            "beta",
            "gamma",
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic,
            loremStatic
        ]
        var note: String? = nil
        if idx % 3 != 0 {
            note = "note with \"quotes\" and \\ backslash"
        }
        let nested = PerfNested(a: idx, b: [idx, idx + 1, idx + 2], c: "nested")
        let item = PerfItem(id: "id-\(idx)",
                            index: idx,
                            score: Double(idx) * 1.5,
                            active: idx % 2 == 0,
                            tags: tags,
                            note: note,
                            nested: nested)
        items.append(item)
    }
    let payload = PerfPayload(version: 3, items: items)
    return (try? JSONEncoder().encode(payload)) ?? Data()
}

class SpankerTestsDecodablePerformance: TestsBase {

    // ~2000 items lands around 300 KB, close to a realistic API response.
    // Bump this to match your own payloads before drawing conclusions.
    fileprivate static let itemCount = 2000

    fileprivate var payload: Data = Data()

    override func setUp() {
        payload = makePerfPayload(Self.itemCount)
    }

    // MARK: - Correctness

    // Guards the benchmarks below: a decoder that silently drops fields would
    // otherwise look wonderfully fast.
    func test_decoder_matches_jsondecoder() {
        let small = makePerfPayload(50)

        guard let viaFoundation = try? JSONDecoder().decode(PerfPayload.self, from: small) else {
            return XCTFail("JSONDecoder failed on the fixture")
        }
        guard let viaSpanker: PerfPayload = try? Spanker.decoded(data: small) else {
            return XCTFail("Spanker.decoded returned nil")
        }

        XCTAssertEqual(viaFoundation, viaSpanker)
        XCTAssertEqual(viaSpanker.items.count, 50)
        // Optionals, nested arrays and escaped strings are the usual places a
        // hand-written decoder goes wrong.
        XCTAssertEqual(viaSpanker.items.filter { $0.note == nil }.count, 17)
        XCTAssertEqual(viaSpanker.items[7].nested.b, [7, 8, 9])
        XCTAssertEqual(viaSpanker.items[1].note, "note with \"quotes\" and \\ backslash")
    }

    func test_decoder_reports_errors() {
        let malformed = Hitch(string: #"{"version": 3, "items": "not an array"}"#)
        let decoded: PerfPayload? = try? Spanker.decoded(hitch: malformed)
        XCTAssertNil(decoded)

        // The throwing entry point should say which path failed.
        let description: String? = malformed.parsed { element -> String? in
            guard let element = element else { return nil }
            do {
                let _: PerfPayload = try element.decoded()
                return nil
            } catch {
                return "\(error)"
            }
        }
        XCTAssertNotNil(description, "expected a decoding error")
        XCTAssertTrue(description?.contains("items") == true, "unexpected error: \(description ?? "nil")")
    }

    // MARK: - CPU

    func test_cpu_jsondecoder() {
        // measured [Time, seconds] average: 0.405, relative standard deviation: 1.110%, values: [0.415703, 0.409285, 0.404863, 0.402067, 0.404659, 0.401326, 0.401121, 0.400774, 0.401382, 0.406148]
        measure {
            for _ in 0..<10 {
                let decoded = try? JSONDecoder().decode(PerfPayload.self, from: payload)
                XCTAssertEqual(decoded?.items.count, Self.itemCount)
            }
        }
    }

    func test_cpu_spanker_decoded() {
        // measured [Time, seconds] average: 0.812, relative standard deviation: 0.713%, values: [0.827393, 0.814264, 0.810159, 0.806815, 0.813177, 0.813115, 0.812573, 0.807328, 0.806168, 0.809847]
        measure {
            for _ in 0..<10 {
                let decoded: PerfPayload? = try? Spanker.decoded(data: payload)
                XCTAssertEqual(decoded?.items.count, Self.itemCount)
            }
        }
    }

    // Isolates the decode step from the parse step, so a slow result can be
    // attributed to one or the other rather than to "Spanker".
    func test_cpu_spanker_parse_only() {
        measure {
            for _ in 0..<10 {
                payload.parsed { element in
                    XCTAssertEqual(element?[element: "items"]?.count, Self.itemCount)
                }
            }
        }
    }

    // MARK: - Memory

    // Peak RSS is monotonic within a process, so whichever of these runs first
    // sets a floor for the other. Run them ONE AT A TIME for the peak numbers to
    // mean anything:
    //
    //   swift test -c release --filter test_memory_jsondecoder
    //   swift test -c release --filter test_memory_spanker_decoded
    //
    // (add --enable-test-discovery on Linux). The "current RSS delta" line is
    // safe to read even when both run in one process.
    //
    // The memory case for this decoder is the stronger one: JSONDecoder re-parses
    // the document and boxes every value as Any/NSNumber before your type sees
    // it, whereas JsonElement strings are HalfHitch slices into the buffer that
    // was already parsed.

    func test_memory_jsondecoder() {
        // [memory] JSONDecoder: current 114 -> 139 MB (delta 25 MB), peak 129 -> 152 MB
        reportMemory("JSONDecoder") {
            let decoded = try? JSONDecoder().decode(PerfPayload.self, from: self.payload)
            XCTAssertEqual(decoded?.items.count, Self.itemCount)
        }
    }

    func test_memory_spanker_decoded() {
        // [memory] Spanker.decoded: current 140 -> 175 MB (delta 35 MB), peak 153 -> 191 MB
        reportMemory("Spanker.decoded") {
            let decoded: PerfPayload? = try? Spanker.decoded(data: self.payload)
            XCTAssertEqual(decoded?.items.count, Self.itemCount)
        }
    }

    func test_memory_spanker_parse_only() {
        reportMemory("Spanker parse only") {
            self.payload.parsed { element in
                XCTAssertEqual(element?[element: "items"]?.count, Self.itemCount)
            }
        }
    }

    fileprivate func reportMemory(_ label: String, _ block: () -> Void) {
        // Warm up so one-time allocations (metadata caches, formatters) do not
        // land in the measured window.
        for _ in 0..<3 { block() }

        let startCurrent = Self.currentResidentMB()
        let startPeak = Self.peakResidentMB()
        for _ in 0..<50 { block() }
        let endCurrent = Self.currentResidentMB()
        let endPeak = Self.peakResidentMB()

        print("[memory] \(label): current \(startCurrent) -> \(endCurrent) MB "
            + "(delta \(endCurrent - startCurrent) MB), peak \(startPeak) -> \(endPeak) MB")
    }

    // MARK: - RSS helpers (Linux, Android and macOS)

    /// Resident set size right now, in MB.
    fileprivate static func currentResidentMB() -> Int {
        #if canImport(Darwin)
        return machResidentMB(peak: false)
        #elseif os(Linux) || os(Android)
        return procStatusMB(field: "VmRSS:")
        #else
        return 0
        #endif
    }

    /// High-water resident set size, in MB. Never decreases within a process.
    fileprivate static func peakResidentMB() -> Int {
        #if canImport(Darwin)
        return machResidentMB(peak: true)
        #elseif os(Linux) || os(Android)
        return procStatusMB(field: "VmHWM:")
        #else
        return 0
        #endif
    }

    #if canImport(Darwin)
    fileprivate static func machResidentMB(peak: Bool) -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let bytes = peak ? info.resident_size_max : info.resident_size
        return Int(bytes) / (1024 * 1024)
    }
    #endif

    #if os(Linux) || os(Android)
    fileprivate static func procStatusMB(field: String) -> Int {
        guard let status = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8) else { return 0 }
        for line in status.split(separator: "\n") where line.hasPrefix(field) {
            let kb = line.split(separator: " ").compactMap { Int($0) }.first ?? 0
            return kb / 1024
        }
        return 0
    }
    #endif
}
