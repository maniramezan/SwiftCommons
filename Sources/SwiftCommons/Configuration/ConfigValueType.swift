/// The primitive kind of a ``ConfigValue``.
///
/// Pairs with ``ConfigValue/init(string:valueType:)`` for the case where a value
/// arrives as text (an environment variable, launch argument, or query item) and
/// its expected type is known separately.
public enum ConfigValueType: Sendable {
    case bool
    case string
    case int
    case double
}
