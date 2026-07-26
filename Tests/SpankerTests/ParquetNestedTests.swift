// NOTE: generated with Claude Opus 4.8

import XCTest
import Foundation

import Spanker
import Hitch

// The shredder's rep/def/value output is pinned to numbers produced by the
// pyarrow-validated reference (nested_ref.py). These checks run in-process and
// need no external tools; they confirm the Swift port reproduces the reference
// exactly. The reference itself is validated by round-tripping the same shapes
// through Apache Arrow.
extension SpankerTests {

    private func leaf(_ table: ParquetNestedTable, _ path: [String]) -> ParquetLeafColumn {
        table.leaves.first { $0.path.map { $0.toString() } == path }!
    }

    private func shred(_ json: String, _ schema: [ParquetSchemaNode]) -> ParquetNestedTable {
        var table: ParquetNestedTable?
        json.parsed { root in
            guard let root = root else { return }
            table = ParquetNestedShredder.shred(schema: schema, records: root.allValues())
        }
        return table!
    }

    func test_nested_scalar_list() throws {
        let schema = [
            ParquetSchemaNode.leaf("a", .int64, .required),
            ParquetSchemaNode.list("tags", .optional,
                                   element: ParquetSchemaNode.leaf("element", .string, .optional)),
        ]
        let json = #"[{"a":1,"tags":["x","y"]},{"a":2,"tags":[]},{"a":3,"tags":null},{"a":4,"tags":["z"]}]"#
        let table = shred(json, schema)

        XCTAssertEqual(table.rowCount, 4)

        let a = leaf(table, ["a"])
        XCTAssertEqual(a.maxDefinitionLevel, 0)
        XCTAssertEqual(a.maxRepetitionLevel, 0)
        XCTAssertEqual(a.repetitionLevels, [0, 0, 0, 0])
        XCTAssertEqual(a.definitionLevels, [0, 0, 0, 0])
        if case .int64(let v) = a.storage { XCTAssertEqual(v, [1, 2, 3, 4]) } else { XCTFail() }

        let tags = leaf(table, ["tags", "list", "element"])
        XCTAssertEqual(tags.maxDefinitionLevel, 3)
        XCTAssertEqual(tags.maxRepetitionLevel, 1)
        XCTAssertEqual(tags.repetitionLevels, [0, 1, 0, 0, 0])
        XCTAssertEqual(tags.definitionLevels, [3, 3, 1, 0, 3])
        if case .bytes(let v) = tags.storage {
            XCTAssertEqual(v.map { $0.toString() }, ["x", "y", "z"])
        } else { XCTFail() }
    }

    func test_nested_person_cap_1() throws {
        // Person with children capped at one level of nesting.
        let schema = [
            ParquetSchemaNode.leaf("name", .string, .optional),
            ParquetSchemaNode.leaf("age", .int64, .optional),
            ParquetSchemaNode.list("children", .optional,
                element: ParquetSchemaNode.group("element", .optional, children: [
                    ParquetSchemaNode.leaf("name", .string, .optional),
                    ParquetSchemaNode.leaf("age", .int64, .optional),
                ])),
        ]
        let json = #"""
        [{"name":"a","age":1,"children":[{"name":"b","age":2},{"name":"c","age":3}]},
         {"name":"d","age":4,"children":[]},
         {"name":"e","age":5,"children":null}]
        """#
        let table = shred(json, schema)

        XCTAssertEqual(table.rowCount, 3)

        let name = leaf(table, ["name"])
        XCTAssertEqual([name.maxDefinitionLevel, name.maxRepetitionLevel], [1, 0])
        XCTAssertEqual(name.repetitionLevels, [0, 0, 0])
        XCTAssertEqual(name.definitionLevels, [1, 1, 1])
        if case .bytes(let v) = name.storage {
            XCTAssertEqual(v.map { $0.toString() }, ["a", "d", "e"])
        } else { XCTFail() }

        let childName = leaf(table, ["children", "list", "element", "name"])
        XCTAssertEqual([childName.maxDefinitionLevel, childName.maxRepetitionLevel], [4, 1])
        XCTAssertEqual(childName.repetitionLevels, [0, 1, 0, 0])
        XCTAssertEqual(childName.definitionLevels, [4, 4, 1, 0])
        if case .bytes(let v) = childName.storage {
            XCTAssertEqual(v.map { $0.toString() }, ["b", "c"])
        } else { XCTFail() }

        let childAge = leaf(table, ["children", "list", "element", "age"])
        XCTAssertEqual(childAge.repetitionLevels, [0, 1, 0, 0])
        XCTAssertEqual(childAge.definitionLevels, [4, 4, 1, 0])
        if case .int64(let v) = childAge.storage { XCTAssertEqual(v, [2, 3]) } else { XCTFail() }
    }

    func test_nested_annotate_levels_and_paths() throws {
        // struct containing a list: verify path + level annotations directly.
        let schema = [
            ParquetSchemaNode.group("addr", .optional, children: [
                ParquetSchemaNode.leaf("street", .string, .optional),
                ParquetSchemaNode.list("zips", .optional,
                                       element: ParquetSchemaNode.leaf("element", .int64, .optional)),
            ]),
        ]
        ParquetSchema.annotate(schema)
        let leaves = ParquetSchema.leaves(of: schema)

        let street = leaves.first { $0.path.map { $0.toString() } == ["addr", "street"] }!
        XCTAssertEqual(street.maxDefinitionLevel, 2)   // addr optional + street optional
        XCTAssertEqual(street.maxRepetitionLevel, 0)

        let zips = leaves.first { $0.path.map { $0.toString() } == ["addr", "zips", "list", "element"] }!
        XCTAssertEqual(zips.maxDefinitionLevel, 4)     // addr + zips-group + repeated + element
        XCTAssertEqual(zips.maxRepetitionLevel, 1)
    }

    private var personSchema: [ParquetSchemaNode] {
        [
            ParquetSchemaNode.leaf("name", .string, .optional),
            ParquetSchemaNode.leaf("age", .int64, .optional),
            ParquetSchemaNode.list("children", .optional,
                element: ParquetSchemaNode.group("element", .optional, children: [
                    ParquetSchemaNode.leaf("name", .string, .optional),
                    ParquetSchemaNode.leaf("age", .int64, .optional),
                ])),
        ]
    }

    func test_nested_encode_envelope() throws {
        let json = #"[{"name":"a","age":1,"children":[{"name":"b","age":2}]},{"name":"c","age":3,"children":[]}]"#
        var data: Data?
        json.parsed { data = $0?.toParquet(schema: personSchema) }
        let b = [UInt8](try XCTUnwrap(data))

        XCTAssertGreaterThan(b.count, 12)
        XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31])
        XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31])
        let metaLen = Int(b[b.count - 8]) | (Int(b[b.count - 7]) << 8)
                    | (Int(b[b.count - 6]) << 16) | (Int(b[b.count - 5]) << 24)
        XCTAssertGreaterThan(metaLen, 0)
        XCTAssertLessThanOrEqual(metaLen, b.count - 12)
    }

    // Opt-in: writes a real nested Parquet file for external validation. No-op
    // unless PARQUET_NESTED_OUT is set.
    //   PARQUET_NESTED_OUT=/tmp/nested.parquet swift test --filter test_nested_write_file
    //   python3 validate.py /tmp/nested.parquet
    func test_nested_write_file() throws {
        guard let path = ProcessInfo.processInfo.environment["PARQUET_NESTED_OUT"] else { return }
        let json = #"""
        [{"name":"alice","age":30,"children":[{"name":"bob","age":10},{"name":"cara","age":8}]},
         {"name":"dan","age":40,"children":[]},
         {"name":"erin","age":50,"children":null}]
        """#
        var data: Data?
        json.parsed { data = $0?.toParquet(schema: personSchema, compression: .snappy) }
        try (data ?? Data()).write(to: URL(fileURLWithPath: path))
        print("wrote \(data?.count ?? 0) bytes to \(path)")
    }

    // Data-driven native nesting (the default toParquet()) on receipt-shaped
    // JSON: struct sometimes-empty, struct always-empty, list of varying-key
    // structs, sparse optional scalar.
    func test_nested_inference_receipts_shape() throws {
        let json = #"""
        [{"store":"A","merchantAddress":{},"billingAddress":{},
          "items":[{"asin":"X","price":"1.00","brand":"B"},{"asin":"Y","price":"2.00"}],"total":"3.00"},
         {"store":"A","merchantAddress":{"name":"Fresh"},"billingAddress":{},
          "items":[{"asin":"Z","price":"5.00"}],"total":"5.00","tip":"1.00"}]
        """#

        var schema: [ParquetSchemaNode] = []
        json.parsed { if let e = $0 { schema = ParquetNestedInference.schema(for: e.allValues()) } }
        func node(_ name: String) -> ParquetSchemaNode { schema.first { $0.name.toString() == name }! }

        XCTAssertEqual(node("merchantAddress").kind, .group)     // some rows populated -> struct
        XCTAssertEqual(node("billingAddress").kind, .leaf)       // empty everywhere -> all-null leaf

        let items = node("items")
        XCTAssertEqual(items.kind, .list)
        let element = try XCTUnwrap(items.element)
        XCTAssertEqual(element.kind, .group)
        XCTAssertEqual(element.children.map { $0.name.toString() }, ["asin", "price", "brand"])
        XCTAssertEqual(element.children[2].repetition, .optional) // brand missing in some items

        XCTAssertEqual(node("tip").kind, .leaf)
        XCTAssertEqual(node("tip").repetition, .optional)

        var data: Data?
        json.parsed { data = $0?.toParquet() }
        let b = [UInt8](try XCTUnwrap(data))
        XCTAssertEqual(Array(b.prefix(4)), [0x50, 0x41, 0x52, 0x31])
        XCTAssertEqual(Array(b.suffix(4)), [0x50, 0x41, 0x52, 0x31])
    }
}

