// NOTE: generated with Claude Opus 4.8

import XCTest

import Spanker
import Hitch

class ParquetShredderTests: TestsBase {

    private func shred(_ json: String) -> ParquetTable {
        let table: ParquetTable? = json.parsed { element in
            element?.toParquetTable()
        }
        return table ?? ParquetTable(rowCount: 0, columns: [])
    }

    private func field(_ table: ParquetTable, _ name: String) -> ParquetField? {
        return table.columns.first { $0.field.name == Hitch(string: name) }?.field
    }

    private func column(_ table: ParquetTable, _ name: String) -> ParquetColumn? {
        return table.columns.first { $0.field.name == Hitch(string: name) }
    }

    // MARK: - Basic record table

    func test_parquet_records_uniform() {
        let t = shred(#"[{"a":1,"b":"x"},{"a":2,"b":"y"}]"#)
        XCTAssertEqual(t.rowCount, 2)
        XCTAssertEqual(t.columns.count, 2)

        // First-appearance column order is preserved.
        XCTAssertEqual(t.columns[0].field.name, Hitch(string: "a"))
        XCTAssertEqual(t.columns[1].field.name, Hitch(string: "b"))

        XCTAssertEqual(field(t, "a")?.type, .int64)
        XCTAssertEqual(field(t, "a")?.nullable, false)
        XCTAssertEqual(field(t, "b")?.type, .string)
        XCTAssertEqual(field(t, "b")?.nullable, false)

        XCTAssertEqual(column(t, "a")?.storage, .int64([1, 2]))
        XCTAssertEqual(column(t, "b")?.storage, .bytes([Hitch(string: "x"), Hitch(string: "y")]))

        // REQUIRED columns carry no definition levels.
        XCTAssertEqual(column(t, "a")?.definitionLevels, [])
        
        print(t.description)
    }

    // MARK: - Nullability: missing key and explicit null

    func test_parquet_nullable_missing_and_explicit_null() {
        // Row 0: b present. Row 1: b missing. Row 2: b explicit null.
        let t = shred(#"[{"a":1,"b":7},{"a":2},{"a":3,"b":null}]"#)
        XCTAssertEqual(t.rowCount, 3)

        XCTAssertEqual(field(t, "a")?.nullable, false)
        XCTAssertEqual(field(t, "b")?.nullable, true)

        // Only the present value is stored; def levels mark presence per row.
        XCTAssertEqual(column(t, "b")?.storage, .int64([7]))
        XCTAssertEqual(column(t, "b")?.definitionLevels, [1, 0, 0])
    }

    // MARK: - Numeric widening

    func test_parquet_int_double_widens_to_double() {
        let t = shred(#"[{"n":1},{"n":2.5},{"n":3}]"#)
        XCTAssertEqual(field(t, "n")?.type, .double)
        XCTAssertEqual(column(t, "n")?.storage, .double([1.0, 2.5, 3.0]))
    }

    // MARK: - Irreconcilable scalar mix falls back to JSON text

    func test_parquet_mixed_scalars_become_json() {
        let t = shred(#"[{"v":1},{"v":"hello"},{"v":true}]"#)
        XCTAssertEqual(field(t, "v")?.type, .json)
        // Values are stored as their JSON text representation, losslessly.
        XCTAssertEqual(column(t, "v")?.storage,
                       .bytes([Hitch(string: "1"),
                               Hitch(string: "\"hello\""),
                               Hitch(string: "true")]))
    }

    // MARK: - Nested values become JSON text (Tier 1)

    func test_parquet_nested_becomes_json() {
        let t = shred(#"[{"o":{"k":1}},{"o":{"k":2}}]"#)
        XCTAssertEqual(field(t, "o")?.type, .json)
        XCTAssertEqual(column(t, "o")?.storage,
                       .bytes([Hitch(string: #"{"k":1}"#),
                               Hitch(string: #"{"k":2}"#)]))
    }

    func test_parquet_array_value_becomes_json() {
        let t = shred(#"[{"tags":["a","b"]},{"tags":[]}]"#)
        XCTAssertEqual(field(t, "tags")?.type, .json)
        XCTAssertEqual(column(t, "tags")?.storage,
                       .bytes([Hitch(string: #"["a","b"]"#),
                               Hitch(string: "[]")]))
    }

    // MARK: - Non-record shapes

    func test_parquet_array_of_scalars_single_column() {
        let t = shred("[1,2,3]")
        XCTAssertEqual(t.rowCount, 3)
        XCTAssertEqual(t.columns.count, 1)
        XCTAssertEqual(t.columns[0].field.name, Hitch(string: "value"))
        XCTAssertEqual(t.columns[0].field.type, .int64)
        XCTAssertEqual(t.columns[0].storage, .int64([1, 2, 3]))
    }

    func test_parquet_single_object_one_row() {
        let t = shred(#"{"a":1,"b":2}"#)
        XCTAssertEqual(t.rowCount, 1)
        XCTAssertEqual(t.columns.count, 2)
        XCTAssertEqual(column(t, "a")?.storage, .int64([1]))
        XCTAssertEqual(column(t, "b")?.storage, .int64([2]))
    }

    func test_parquet_bare_scalar_one_by_one() {
        let t = shred("42")
        XCTAssertEqual(t.rowCount, 1)
        XCTAssertEqual(t.columns.count, 1)
        XCTAssertEqual(t.columns[0].field.name, Hitch(string: "value"))
        XCTAssertEqual(t.columns[0].storage, .int64([42]))
    }

    func test_parquet_empty_array_one_column_zero_rows() {
        let t = shred("[]")
        XCTAssertEqual(t.rowCount, 0)
        XCTAssertEqual(t.columns.count, 1)
        XCTAssertEqual(t.columns[0].field.name, Hitch(string: "value"))
        XCTAssertEqual(t.columns[0].storage, .bytes([]))
    }
}
