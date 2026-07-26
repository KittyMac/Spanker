// NOTE: generated with Claude Opus 4.8

import XCTest
import Foundation

import Spanker
import Hitch

// Schema-from-Codable relies on Swift's synthesized Codable machinery and has
// no external oracle (unlike the byte-format tests, which round-trip through
// pyarrow). These tests pin the expected mapping; run them to confirm the probe
// behaves as intended on your toolchain.
//
// KNOWN LIMITATION reminder: a RawRepresentable enum property, e.g.
//     enum Role: String, Codable { case eng, sales }
//     struct Employee: Codable { let role: Role }
// will make `columns(for: Employee.self)` throw `.unsupportedField`, because the
// probe drives real decoding with a placeholder ("") that Role rejects. Model
// such fields as their raw type (`let role: String`) if you need them as a
// typed column.
class ParquetCodableTests: TestsBase {

    // Exactly the example from the request.
    final class Person: Codable {
        let name: String
        let age: Int
        let occupation: String?
        let children: [Person]
    }

    func test_codable_schema_person() throws {
        let columns = try ParquetCodableSchema.columns(for: Person.self)
        XCTAssertEqual(columns, [
            ParquetField(name: "name",       type: .string, nullable: false),
            ParquetField(name: "age",        type: .int64,  nullable: false),
            ParquetField(name: "occupation", type: .string, nullable: true),
            ParquetField(name: "children",   type: .json,   nullable: false),
        ])
    }

    struct AllPrimitives: Codable {
        let flag: Bool
        let small: Int8
        let big: Int64
        let count: UInt32
        let ratio: Float
        let precise: Double
        let label: String
        let maybeInt: Int?
        let maybeText: String?
    }

    func test_codable_schema_primitives() throws {
        let columns = try ParquetCodableSchema.columns(for: AllPrimitives.self)
        XCTAssertEqual(columns, [
            ParquetField(name: "flag",      type: .boolean, nullable: false),
            ParquetField(name: "small",     type: .int64,   nullable: false),
            ParquetField(name: "big",       type: .int64,   nullable: false),
            ParquetField(name: "count",     type: .int64,   nullable: false),
            ParquetField(name: "ratio",     type: .double,  nullable: false),
            ParquetField(name: "precise",   type: .double,  nullable: false),
            ParquetField(name: "label",     type: .string,  nullable: false),
            ParquetField(name: "maybeInt",  type: .int64,   nullable: true),
            ParquetField(name: "maybeText", type: .string,  nullable: true),
        ])
    }

    struct Nested: Codable {
        let id: Int
        let tags: [String]          // array -> json
        let meta: [String: Int]     // dictionary -> json
        let opt: [Int]?             // optional array -> json, nullable
    }

    func test_codable_schema_nested_becomes_json() throws {
        let columns = try ParquetCodableSchema.columns(for: Nested.self)
        XCTAssertEqual(columns, [
            ParquetField(name: "id",   type: .int64, nullable: false),
            ParquetField(name: "tags", type: .json,  nullable: false),
            ParquetField(name: "meta", type: .json,  nullable: false),
            ParquetField(name: "opt",  type: .json,  nullable: true),
        ])
    }

    func test_codable_schema_single_value() throws {
        XCTAssertEqual(try ParquetCodableSchema.columns(for: Int.self),
                       [ParquetField(name: "value", type: .int64, nullable: false)])
        XCTAssertEqual(try ParquetCodableSchema.columns(for: String.self),
                       [ParquetField(name: "value", type: .string, nullable: false)])
    }

    // Example: set the schema once from Person.self, then stream people in over
    // time (each arriving and parsed separately), letting the writer flush row
    // groups automatically. Reads the file back to confirm a valid envelope.
    func test_stream_people_over_time() throws {
        let url = URL(fileURLWithPath: "/tmp/people_stream_test.parquet")

        let sink = try ParquetFileSink(url: url)
        let stream = try ParquetStreamWriter(
            sink: sink,
            rowType: Person.self,
            writeOptions: ParquetWriteOptions(rowsPerRowGroup: 3)   // small, to force >1 row group
        )

        // People arrive one at a time; parse each and append.
        let arrivals = [
            #"{"name":"Alice","age":30,"occupation":"engineer","children":[]}"#,
            #"{"name":"Bob","age":25,"children":[]}"#,
            #"{"name":"Carol","age":41,"occupation":"doctor","children":[{"name":"Dan","age":9,"children":[]}]}"#,
            #"{"name":"Eve","age":22,"children":[]}"#,
            #"{"name":"Frank","age":50,"occupation":"chef","children":[]}"#,
        ]
        for line in arrivals {
            line.parsed { element in
                if let element = element { stream.append(element) }
            }
        }
        stream.finish()      // flushes the final partial row group + footer
        sink.close()

        XCTAssertEqual(stream.schema.map { $0.name.toString() },
                       ["name", "age", "occupation", "children"])

        let data = try Data(contentsOf: url)
        let b = [UInt8](data)
        XCTAssertGreaterThan(b.count, 12)
        XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31])
        XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31])
    }

    // Derive a native nested schema tree from Person.self with recursion capped
    // at 2 levels. name/age are required, occupation nullable, children a
    // required list; the second children level omits its own children (cap).
    func test_nested_codable_person_schema() throws {
        let cols = ParquetCodableSchema.nestedColumns(for: Person.self, maxRecursionDepth: 2)

        XCTAssertEqual(cols.map { $0.name.toString() }, ["name", "age", "occupation", "children"])
        XCTAssertEqual(cols[0].kind, .leaf)
        XCTAssertEqual(cols[0].type, .string)
        XCTAssertEqual(cols[0].repetition, .required)
        XCTAssertEqual(cols[1].type, .int64)
        XCTAssertEqual(cols[1].repetition, .required)
        XCTAssertEqual(cols[2].type, .string)
        XCTAssertEqual(cols[2].repetition, .optional)   // occupation: String?

        let children = cols[3]
        XCTAssertEqual(children.kind, .list)
        XCTAssertEqual(children.repetition, .required)   // children: [Person] (non-optional)

        let level1 = try XCTUnwrap(children.element)
        XCTAssertEqual(level1.kind, .group)
        XCTAssertEqual(level1.children.map { $0.name.toString() }, ["name", "age", "occupation", "children"])

        let level2 = try XCTUnwrap(level1.children[3].element)
        XCTAssertEqual(level2.kind, .group)
        // Cap reached: the deepest Person has no children field.
        XCTAssertEqual(level2.children.map { $0.name.toString() }, ["name", "age", "occupation"])
    }

    func test_nested_codable_end_to_end_envelope() throws {
        let json = #"""
        [{"name":"alice","age":30,"occupation":"eng","children":[{"name":"bob","age":10,"children":[]}]},
         {"name":"dan","age":40,"children":[]}]
        """#
        var data: Data?
        json.parsed { data = $0?.toParquet(codable: Person.self, maxRecursionDepth: 2) }
        let b = [UInt8](try XCTUnwrap(data))
        XCTAssertGreaterThan(b.count, 12)
        XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31])
        XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31])
    }

    // Streaming, but with NATIVE nesting: children is a real list<struct>, not a
    // JSON string. This is the nested counterpart of test_stream_people_over_time.
    func test_nested_stream_people_over_time() throws {
        let url = URL(fileURLWithPath: "/tmp/people_nested_stream_test.parquet")

        let sink = try ParquetFileSink(url: url)
        let stream = ParquetNestedStreamWriter(
            sink: sink,
            rowType: Person.self,
            maxRecursionDepth: 2,
            writeOptions: ParquetWriteOptions(rowsPerRowGroup: 3)   // force >1 row group
        )

        let arrivals = [
            #"{"name":"Alice","age":30,"occupation":"engineer","children":[]}"#,
            #"{"name":"Bob","age":25,"children":[]}"#,
            #"{"name":"Carol","age":41,"occupation":"doctor","children":[{"name":"Dan","age":9,"children":[]}]}"#,
            #"{"name":"Eve","age":22,"children":[]}"#,
            #"{"name":"Frank","age":50,"occupation":"chef","children":[]}"#,
        ]
        for line in arrivals {
            line.parsed { element in
                if let element = element { stream.append(element) }
            }
        }
        stream.finish()
        sink.close()

        // children is a native LIST node in the schema, not a JSON leaf.
        let children = stream.schema.first { $0.name == "children" }!
        XCTAssertEqual(children.kind, .list)

        let b = [UInt8](try Data(contentsOf: url))
        XCTAssertGreaterThan(b.count, 12)
        XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31])
        XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31])
    }
}



