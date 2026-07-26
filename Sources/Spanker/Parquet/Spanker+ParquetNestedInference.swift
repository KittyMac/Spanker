// NOTE: generated with Claude Opus 4.8

import Foundation
import Hitch

// MARK: - Native nested schema inference from data
//
// Infers a ParquetSchemaNode tree from JSON records: objects become GROUP nodes
// (their fields unioned across all rows in first-appearance order), arrays
// become LIST nodes (element inferred from all elements), scalars become leaves
// with int/double/string widening. Rules matching the agreed semantics:
//   * an empty object {} counts as null (contributes no keys, marks nullable)
//   * a field that is empty/absent in every row has no structure to infer, so
//     it becomes an all-null leaf column
//   * a field with irreconcilable kinds across rows falls back to a JSON leaf
// Validated against Apache Arrow on receipt-shaped data.

public enum ParquetNestedInference {

    /// Infer a nested schema from a list of record objects.
    public static func schema(for records: [JsonElement]) -> [ParquetSchemaNode] {
        return inferGroupFields(records)
    }

    private enum ValueKind: Hashable { case object, array, scalar }

    private static func isNullish(_ e: JsonElement) -> Bool {
        if e.type == .null { return true }
        if e.type == .dictionary && e.keyArray.isEmpty { return true }   // empty object == null
        return false
    }

    private static func kind(of e: JsonElement) -> ValueKind {
        switch e.type {
        case .dictionary: return .object
        case .array:      return .array
        default:          return .scalar
        }
    }

    private static func lookup(_ e: JsonElement) -> [HalfHitch: JsonElement] {
        guard e.type == .dictionary else { return [:] }
        var map: [HalfHitch: JsonElement] = [:]
        let keys = e.keyArray
        let vals = e.valueArray
        let n = min(keys.count, vals.count)
        map.reserveCapacity(n)
        for i in 0..<n where map[keys[i]] == nil { map[keys[i]] = vals[i] }
        return map
    }

    private static func inferGroupFields(_ objects: [JsonElement]) -> [ParquetSchemaNode] {
        // Union of keys, first-appearance order.
        var order: [Hitch] = []
        var seen = Set<HalfHitch>()
        let lookups = objects.map { lookup($0) }
        for obj in objects where obj.type == .dictionary {
            for key in obj.keyArray where !seen.contains(key) {
                seen.insert(key)
                order.append(key.hitch())
            }
        }

        var nodes: [ParquetSchemaNode] = []
        nodes.reserveCapacity(order.count)
        for key in order {
            let hh = key.halfhitch()
            var values: [JsonElement] = []
            var missing = 0
            for lk in lookups {
                if let v = lk[hh], !isNullish(v) { values.append(v) } else { missing += 1 }
            }
            nodes.append(inferNode(name: key, values: values, optional: missing > 0))
        }
        return nodes
    }

    private static func inferNode(name: Hitch, values: [JsonElement], optional: Bool) -> ParquetSchemaNode {
        let rep: ParquetRepetition = optional ? .optional : .required
        if values.isEmpty {
            return .leaf(name, .string, .optional)   // no representative content -> all null
        }
        let kinds = Set(values.map { kind(of: $0) })
        if kinds == [.object] {
            let children = inferGroupFields(values)
            return children.isEmpty ? .leaf(name, .string, .optional)
                                    : .group(name, rep, children: children)
        }
        if kinds == [.array] {
            var elements: [JsonElement] = []
            for v in values { elements.append(contentsOf: v.valueArray) }
            return .list(name, rep, element: inferElement(elements))
        }
        if kinds == [.scalar] {
            return .leaf(name, inferScalarType(values), rep)
        }
        return .leaf(name, .json, rep)   // irreconcilable mix
    }

    private static func inferElement(_ elements: [JsonElement]) -> ParquetSchemaNode {
        let nonNull = elements.filter { !isNullish($0) }
        if nonNull.isEmpty { return .leaf("element", .string, .optional) }
        let kinds = Set(nonNull.map { kind(of: $0) })
        if kinds == [.object] {
            let children = inferGroupFields(nonNull)
            return children.isEmpty ? .leaf("element", .string, .optional)
                                    : .group("element", .optional, children: children)
        }
        if kinds == [.array] {
            var inner: [JsonElement] = []
            for e in nonNull { inner.append(contentsOf: e.valueArray) }
            return .list("element", .optional, element: inferElement(inner))
        }
        if kinds == [.scalar] {
            return .leaf("element", inferScalarType(nonNull), .optional)
        }
        return .leaf("element", .json, .optional)
    }

    // MARK: Scalar widening

    private enum Scalar { case unknown, boolean, int64, double, string, json }

    private static func inferScalarType(_ values: [JsonElement]) -> ParquetLogicalType {
        var t: Scalar = .unknown
        for v in values { t = join(t, scalar(of: v)) }
        switch t {
        case .unknown, .string: return .string
        case .boolean:          return .boolean
        case .int64:            return .int64
        case .double:           return .double
        case .json:             return .json
        }
    }

    private static func scalar(of e: JsonElement) -> Scalar {
        switch e.type {
        case .boolean:        return .boolean
        case .int:            return .int64
        case .double:         return .double
        case .string, .regex: return .string
        default:              return .json
        }
    }

    private static func join(_ a: Scalar, _ b: Scalar) -> Scalar {
        if a == b { return a }
        switch (a, b) {
        case (.unknown, let x), (let x, .unknown): return x
        case (.int64, .double), (.double, .int64): return .double
        default:                                   return .json
        }
    }
}
