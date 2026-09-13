import Foundation

/// A process-wide, thread-local cache for `Formatter` instances.
///
/// Configuring Foundation formatters can be expensive. Caching one instance per
/// (formatter type, cache key, thread) avoids repeated configuration and keeps each thread's
/// mutable formatter state separate.
///
/// Treat returned instances as read-only. Use them synchronously on the calling thread;
/// do not retain them across suspension points or pass them to another thread or task.
/// Entries remain cached for the lifetime of their thread, so prefer a bounded set of
/// configuration keys rather than keys derived from individual values being formatted.
///
///     extension NumberFormatter {
///         static func formatDistance(_ value: Double, locale: Locale) -> String {
///             let formatter = FormatterCache.formatter(for: "distance|\(locale.identifier)") {
///                 let formatter = NumberFormatter()
///                 formatter.locale = locale
///                 formatter.numberStyle = .decimal
///                 return formatter
///             }
///             return formatter.string(from: value as NSNumber) ?? String(value)
///         }
///     }
public enum FormatterCache {
    /// Returns the cached formatter for `key`, creating and configuring it via `make` on a miss.
    ///
    /// `key` should encode every input that affects the formatter's configuration (locale,
    /// calendar, time zone, format pattern, and so on) — two calls with the same key but
    /// different `make` closures return whichever formatter was cached first. The formatter
    /// type itself is folded into the underlying storage key, so distinct formatter types never
    /// collide even when given the same `key` string.
    ///
    /// - Parameters:
    ///   - key: A string uniquely identifying this formatter's configuration.
    ///   - make: Builds and configures a new formatter on a cache miss. Not called on a hit.
    public static func formatter<F: Formatter>(for key: String, make: () -> F) -> F {
        let storageKey = "com.swiftcommons.formattercache.\(ObjectIdentifier(F.self))|\(key)"
        let threadCache = Thread.current.threadDictionary

        if let cached = threadCache[storageKey] as? F {
            return cached
        }

        let formatter = make()
        threadCache[storageKey] = formatter
        return formatter
    }
}
