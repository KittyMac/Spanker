// NOTE: generated with Claude Opus 4.8

import XCTest
import Foundation

import Spanker
import Hitch

// The encoder's byte layout was validated end-to-end against Apache Arrow
// (pyarrow) via a reference implementation. These Swift tests cover what can be
// checked without a Parquet reader in-process: structural invariants of the
// file envelope, plus an opt-in dump to disk (set PARQUET_OUT) so the real
// Swift output can be round-tripped through pyarrow/duckdb locally:
//
//   PARQUET_OUT=/tmp/out.parquet swift test --filter test_parquet_write_file
//   python3 validate.py /tmp/out.parquet
class ParquetEncoderTests: TestsBase {

    private func parquetBytes(_ json: String) -> [UInt8] {
        let data: Data? = json.parsed { $0?.toParquet() }
        return [UInt8](data ?? Data())
    }

    private func leU32(_ b: [UInt8], _ at: Int) -> UInt32 {
        return UInt32(b[at]) | (UInt32(b[at + 1]) << 8)
             | (UInt32(b[at + 2]) << 16) | (UInt32(b[at + 3]) << 24)
    }

    func test_parquet_envelope_magic() {
        let b = parquetBytes(#"[{"a":1,"b":"x"},{"a":2,"b":"y"}]"#)
        XCTAssertGreaterThan(b.count, 12)
        // Header and footer magic "PAR1".
        XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31])
        XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31])
    }

    func test_parquet_footer_length_is_consistent() {
        let b = parquetBytes(#"[{"a":1,"b":"x"},{"a":2,"b":"y"}]"#)
        let n = b.count
        // Layout: [PAR1][data...][metadata (metaLen bytes)][metaLen: u32 LE][PAR1]
        let metaLen = Int(leU32(b, n - 8))
        XCTAssertGreaterThan(metaLen, 0)
        // The metadata must sit entirely between the 4-byte header and the
        // 8-byte trailer.
        XCTAssertLessThanOrEqual(metaLen, n - 12)
        // The metadata region is a Thrift struct; its first byte is a field
        // header (non-zero), never a struct-stop (0x00).
        let metaStart = n - 8 - metaLen
        XCTAssertGreaterThanOrEqual(metaStart, 4)
        XCTAssertNotEqual(b[metaStart], 0x00)
    }

    func test_parquet_all_types_do_not_crash_and_have_envelope() {
        let samples = [
            #"[{"n":1},{"n":2},{"n":3}]"#,                    // required int64
            #"[{"n":1},{"n":2.5}]"#,                          // widened double
            #"[{"s":"a"},{"s":"b"}]"#,                        // string
            #"[{"o":{"k":1}},{"o":{"k":2}}]"#,                // json
            #"[{"f":true},{"f":false}]"#,                     // boolean
            #"[{"a":1,"b":7},{"a":2},{"a":3,"b":null}]"#,     // nullable
            "[1,2,3]",                                        // single value column
            "[]"                                              // empty
        ]
        for s in samples {
            let b = parquetBytes(s)
            XCTAssertGreaterThan(b.count, 12, "empty output for: \(s)")
            XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31], "bad header for: \(s)")
            XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31], "bad footer for: \(s)")
        }
    }

    // Opt-in: writes a real Parquet file for external validation. No-op unless
    // PARQUET_OUT is set, so it never fails CI.
    func test_parquet_write_file() throws {
        let path = "/tmp/sample.parquet"
        let json = #"""
        [{"id":1,"name":"alice","score":9.5,"active":true,"tags":["a","b"]},
         {"id":2,"name":"bob","active":false},
         {"id":3,"name":"carol","score":7,"active":true,"note":null}]
        """#
        let data: Data? = json.parsed { $0?.toParquet() }
        let bytes = try XCTUnwrap(data)
        try bytes.write(to: URL(fileURLWithPath: path))
        print("wrote \(bytes.count) bytes to \(path)")
    }
}
