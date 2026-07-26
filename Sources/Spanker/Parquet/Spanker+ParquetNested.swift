// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Native nested schema + Dremel shredding
//
// Represents structs (GROUP), lists (the 3-level LIST encoding), and leaves,
// and stripes a `JsonElement` tree into per-leaf columns carrying repetition
// and definition levels. The level arithmetic and the LIST expansion mirror
// `nested_ref.py`, which is validated end-to-end against Apache Arrow.
//
// A LIST field `name` expands physically to:
//     <rep> group name (LIST) { repeated group "list" { <element> } }
// so a leaf beneath an optional list of optional scalars reaches max def 3,
// max rep 1.

public enum ParquetRepetition: UInt8, Equatable {
    case required = 0
    case optional = 1
    case repeated = 2
}

// MARK: - Schema node

public final class ParquetSchemaNode {
    public enum Kind: Equatable { case leaf, group, list }

    public let kind: Kind
    public let name: Hitch
    public let repetition: ParquetRepetition
    public let type: ParquetLogicalType            // meaningful for .leaf
    public let children: [ParquetSchemaNode]        // .group
    public let element: ParquetSchemaNode?          // .list (always named "element")

    // Filled in by `ParquetSchema.annotate`.
    public internal(set) var path: [Hitch] = []
    public internal(set) var maxDefinitionLevel = 0
    public internal(set) var maxRepetitionLevel = 0
    internal var leafIndex = -1

    private init(kind: Kind, name: Hitch, repetition: ParquetRepetition,
                 type: ParquetLogicalType, children: [ParquetSchemaNode], element: ParquetSchemaNode?) {
        self.kind = kind
        self.name = name
        self.repetition = repetition
        self.type = type
        self.children = children
        self.element = element
    }

    public static func leaf(_ name: Hitch, _ type: ParquetLogicalType,
                            _ repetition: ParquetRepetition = .optional) -> ParquetSchemaNode {
        ParquetSchemaNode(kind: .leaf, name: name, repetition: repetition,
                          type: type, children: [], element: nil)
    }

    public static func group(_ name: Hitch, _ repetition: ParquetRepetition = .optional,
                             children: [ParquetSchemaNode]) -> ParquetSchemaNode {
        ParquetSchemaNode(kind: .group, name: name, repetition: repetition,
                          type: .json, children: children, element: nil)
    }

    public static func list(_ name: Hitch, _ repetition: ParquetRepetition = .optional,
                            element: ParquetSchemaNode) -> ParquetSchemaNode {
        // The element node is always named "element" in the physical schema.
        ParquetSchemaNode(kind: .list, name: name, repetition: repetition,
                          type: .json, children: [], element: element.withName("element"))
    }

    private func withName(_ newName: Hitch) -> ParquetSchemaNode {
        ParquetSchemaNode(kind: kind, name: newName, repetition: repetition,
                          type: type, children: children, element: element)
    }

    var optPlus: Int { repetition == .optional ? 1 : 0 }
}

// MARK: - Annotation

public enum ParquetSchema {
    /// Assign `path`, `maxDefinitionLevel`, `maxRepetitionLevel`, and a
    /// pre-order leaf index to every node. Idempotent.
    public static func annotate(_ schema: [ParquetSchemaNode]) {
        var leafCounter = 0
        for node in schema {
            annotateNode(node, defAcc: 0, repAcc: 0, path: [], leafCounter: &leafCounter)
        }
    }

    private static func annotateNode(_ node: ParquetSchemaNode, defAcc: Int, repAcc: Int,
                                     path: [Hitch], leafCounter: inout Int) {
        let p = path + [node.name]
        node.path = p
        switch node.kind {
        case .leaf:
            node.maxDefinitionLevel = defAcc + node.optPlus
            node.maxRepetitionLevel = repAcc
            node.leafIndex = leafCounter
            leafCounter += 1
        case .group:
            let d = defAcc + node.optPlus
            for child in node.children {
                annotateNode(child, defAcc: d, repAcc: repAcc, path: p, leafCounter: &leafCounter)
            }
        case .list:
            // The LIST group contributes its own optional bit; the repeated
            // "list" wrapper always adds +1 def and +1 rep.
            let dList = defAcc + node.optPlus
            annotateNode(node.element!, defAcc: dList + 1, repAcc: repAcc + 1,
                         path: p + ["list"], leafCounter: &leafCounter)
        }
    }

    /// Leaves in pre-order (matching the assigned leaf indices).
    public static func leaves(of schema: [ParquetSchemaNode]) -> [ParquetSchemaNode] {
        var out: [ParquetSchemaNode] = []
        for node in schema { collectLeaves(node, into: &out) }
        return out
    }

    static func collectLeaves(_ node: ParquetSchemaNode, into out: inout [ParquetSchemaNode]) {
        switch node.kind {
        case .leaf:  out.append(node)
        case .group: for c in node.children { collectLeaves(c, into: &out) }
        case .list:  collectLeaves(node.element!, into: &out)
        }
    }
}

// MARK: - Shredded output

/// One leaf column after shredding: repetition + definition levels for every
/// slot, and the present (non-null) values.
public struct ParquetLeafColumn {
    public let path: [Hitch]
    public let type: ParquetLogicalType
    public let maxDefinitionLevel: Int
    public let maxRepetitionLevel: Int
    public let repetitionLevels: [UInt8]
    public let definitionLevels: [UInt8]
    public let storage: ParquetColumnStorage
}

public struct ParquetNestedTable {
    public let rowCount: Int
    public let leaves: [ParquetLeafColumn]
}

// MARK: - Shredder

public enum ParquetNestedShredder {
    /// Stripe `records` (each a JSON object) into leaf columns using `schema`.
    public static func shred(schema: [ParquetSchemaNode], records: [JsonElement]) -> ParquetNestedTable {
        ParquetSchema.annotate(schema)
        let leafNodes = ParquetSchema.leaves(of: schema)
        let buffers = leafNodes.map { LeafBuffer(type: $0.type) }

        for record in records {
            let lookup = buildLookup(record)
            for node in schema {
                strip(node, value: lookup[node.name.halfhitch()],
                      rep: 0, def: 0, repDepth: 0, buffers: buffers)
            }
        }

        let leaves = zip(leafNodes, buffers).map { node, buf in
            ParquetLeafColumn(path: node.path, type: node.type,
                              maxDefinitionLevel: node.maxDefinitionLevel,
                              maxRepetitionLevel: node.maxRepetitionLevel,
                              repetitionLevels: buf.reps, definitionLevels: buf.defs,
                              storage: buf.finish())
        }
        return ParquetNestedTable(rowCount: records.count, leaves: leaves)
    }

    private static func isNull(_ value: JsonElement?) -> Bool {
        guard let value = value else { return true }
        if value.type == .null { return true }
        if value.type == .dictionary && value.keyArray.isEmpty { return true }   // empty object == null
        return false
    }

    fileprivate static func strip(_ node: ParquetSchemaNode, value: JsonElement?,
                              rep: Int, def: Int, repDepth: Int, buffers: [LeafBuffer]) {
        switch node.kind {
        case .leaf:
            let buf = buffers[node.leafIndex]
            if isNull(value) {
                buf.emit(rep: rep, def: def, value: nil)
            } else {
                buf.emit(rep: rep, def: def + node.optPlus, value: value)
            }

        case .group:
            if isNull(value) {
                emitNulls(under: node, rep: rep, def: def, buffers: buffers)
            } else {
                let d = def + node.optPlus
                let lookup = buildLookup(value!)
                for child in node.children {
                    strip(child, value: lookup[child.name.halfhitch()],
                          rep: rep, def: d, repDepth: repDepth, buffers: buffers)
                }
            }

        case .list:
            guard isNull(value) == false, value!.type == .array else {
                emitNulls(under: node, rep: rep, def: def, buffers: buffers)
                return
            }
            let items = value!.valueArray
            let dList = def + node.optPlus
            if items.isEmpty {
                // Present but empty: element leaves get one null at the
                // list-present level (the repeated wrapper is not entered).
                emitNulls(under: node.element!, rep: rep, def: dList, buffers: buffers)
            } else {
                for (i, item) in items.enumerated() {
                    let r = (i == 0) ? rep : (repDepth + 1)
                    strip(node.element!, value: item, rep: r, def: dList + 1,
                          repDepth: repDepth + 1, buffers: buffers)
                }
            }
        }
    }

    fileprivate static func emitNulls(under node: ParquetSchemaNode, rep: Int, def: Int, buffers: [LeafBuffer]) {
        var leaves: [ParquetSchemaNode] = []
        ParquetSchema.collectLeaves(node, into: &leaves)
        for leaf in leaves { buffers[leaf.leafIndex].emit(rep: rep, def: def, value: nil) }
    }

    fileprivate static func buildLookup(_ element: JsonElement) -> [HalfHitch: JsonElement] {
        guard element.type == .dictionary else { return [:] }
        var map: [HalfHitch: JsonElement] = [:]
        let keys = element.keyArray
        let vals = element.valueArray
        let n = min(keys.count, vals.count)
        map.reserveCapacity(n)
        for i in 0..<n where map[keys[i]] == nil { map[keys[i]] = vals[i] }   // first occurrence wins
        return map
    }
}

// MARK: - Leaf value/level buffer

fileprivate final class LeafBuffer {
    let type: ParquetLogicalType
    var reps: [UInt8] = []
    var defs: [UInt8] = []

    private var bools: [Bool] = []
    private var ints: [Int64] = []
    private var doubles: [Double] = []
    private var bytes: [Hitch] = []

    init(type: ParquetLogicalType) { self.type = type }

    func emit(rep: Int, def: Int, value: JsonElement?) {
        reps.append(UInt8(rep))
        defs.append(UInt8(def))
        guard let v = value else { return }
        switch type {
        case .boolean: bools.append(v.valueBool)
        case .int64:   ints.append(Int64(v.valueInt))
        case .double:  doubles.append(v.type == .int ? Double(v.valueInt) : v.valueDouble)
        case .string:  bytes.append(v.valueString.hitch())
        case .json:    bytes.append(v.toHitch())
        }
    }

    func finish() -> ParquetColumnStorage {
        switch type {
        case .boolean:       return .boolean(bools)
        case .int64:         return .int64(ints)
        case .double:        return .double(doubles)
        case .string, .json: return .bytes(bytes)
        }
    }
}

// MARK: - Nested row accumulator (streaming)

/// Buffers records one at a time against a fixed nested schema, stripping each
/// into persistent leaf buffers, and hands off a row group's leaf columns on
/// demand. Values are copied on append, so callers may append from short-lived
/// JsonElements (e.g. inside `parsed`).
final class NestedRowAccumulator {
    let schema: [ParquetSchemaNode]
    private let leafNodes: [ParquetSchemaNode]
    private var buffers: [LeafBuffer]
    private(set) var rowCount = 0

    init(schema: [ParquetSchemaNode]) {
        ParquetSchema.annotate(schema)
        self.schema = schema
        self.leafNodes = ParquetSchema.leaves(of: schema)
        self.buffers = leafNodes.map { LeafBuffer(type: $0.type) }
    }

    func append(_ record: JsonElement) {
        let lookup = ParquetNestedShredder.buildLookup(record)
        for node in schema {
            ParquetNestedShredder.strip(node, value: lookup[node.name.halfhitch()],
                                        rep: 0, def: 0, repDepth: 0, buffers: buffers)
        }
        rowCount += 1
    }

    /// Finalize buffered rows into leaf columns and reset for the next group.
    func takeRowGroup() -> (leaves: [ParquetLeafColumn], rowCount: Int) {
        let leaves = zip(leafNodes, buffers).map { node, buf in
            ParquetLeafColumn(path: node.path, type: node.type,
                              maxDefinitionLevel: node.maxDefinitionLevel,
                              maxRepetitionLevel: node.maxRepetitionLevel,
                              repetitionLevels: buf.reps, definitionLevels: buf.defs,
                              storage: buf.finish())
        }
        let rc = rowCount
        buffers = leafNodes.map { LeafBuffer(type: $0.type) }
        rowCount = 0
        return (leaves, rc)
    }
}
