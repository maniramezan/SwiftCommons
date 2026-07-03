import Foundation

/// A type-safe configuration value with lenient cross-type coercion.
///
/// Useful for remote- or local-config systems where a stored value may arrive
/// as a different primitive than the call site expects. Each accessor coerces
/// from the underlying case:
///
///     ConfigValue.string("true").boolValue  // true
///     ConfigValue.int(0).boolValue           // false
///     ConfigValue.double(3.9).intValue        // 3
public enum ConfigValue: Sendable, Hashable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)

    // MARK: - Convenience accessors

    /// The value as a `Bool`. Strings of `"true"` or `"1"` and non-zero
    /// numbers are `true`.
    public var boolValue: Bool {
        switch self {
        case .bool(let v): v
        case .string(let v): v.lowercased() == "true" || v == "1"
        case .int(let v): v != 0
        case .double(let v): v != 0
        }
    }

    /// The value as a `String`.
    public var stringValue: String {
        switch self {
        case .bool(let v): String(v)
        case .string(let v): v
        case .int(let v): String(v)
        case .double(let v): String(v)
        }
    }

    /// The value as an `Int`. Unparseable strings coerce to `0`; doubles are
    /// truncated.
    public var intValue: Int {
        switch self {
        case .bool(let v): v ? 1 : 0
        case .string(let v): Int(v) ?? 0
        case .int(let v): v
        case .double(let v): Int(v)
        }
    }

    /// The value as a `Double`. Unparseable strings coerce to `0`.
    public var doubleValue: Double {
        switch self {
        case .bool(let v): v ? 1.0 : 0.0
        case .string(let v): Double(v) ?? 0.0
        case .int(let v): Double(v)
        case .double(let v): v
        }
    }

    // MARK: - Loading

    /// Builds a `[String: ConfigValue]` dictionary from process environment
    /// variables, wrapping every value as `.string`.
    ///
    /// Environment variables are always strings, so callers rely on the
    /// lenient coercion accessors (``boolValue``, ``intValue``, ``doubleValue``)
    /// to read them as other types:
    ///
    ///     let config = ConfigValue.environment()
    ///     let isDebug = config["DEBUG_MODE"]?.boolValue ?? false
    ///
    /// - Parameter environment: The environment to read from. Defaults to
    ///   `ProcessInfo.processInfo.environment`.
    /// - Returns: A dictionary mapping each environment variable name to its
    ///   `.string` value.
    public static func environment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: ConfigValue] {
        environment.mapValues { .string($0) }
    }
}
