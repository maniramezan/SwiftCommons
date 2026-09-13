import Foundation
import OSLog

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
///     struct NumberKey: Hashable {
///         let locale: Locale
///     }
///     let formatter: NumberFormatter = FormatterCache.formatter(
///         for: NumberKey(locale: .current)
///     ) {
///         let formatter = NumberFormatter()
///         formatter.locale = .current
///         formatter.numberStyle = .decimal
///         return formatter
///     }
public enum FormatterCache {
    private static let logger: Logger = .swiftCommonsLogger(for: FormatterCache.self)

    private struct EntryKey: Hashable {
        let formatterType: ObjectIdentifier
        let keyType: ObjectIdentifier
        let configuration: AnyHashable
    }

    private final class Storage {
        var formatters: [EntryKey: Formatter] = [:]
    }

    /// Returns the thread-local formatter for a hashable configuration, creating it on a miss.
    ///
    /// Include every configuration input in `key`. Prefer a dedicated `Hashable` struct or enum;
    /// strings remain supported. Formatter and key types have independent namespaces, so
    /// unrelated key types cannot collide even when their erased values compare equal.
    /// Equal keys return the first configured instance; `make` is not called on cache hits.
    /// - Parameters:
    ///   - key: An immutable value identifying the complete formatter configuration.
    ///   - make: Builds and configures a new formatter on a cache miss.
    public static func formatter<Key: Hashable, F: Formatter>(for key: Key, make: () -> F) -> F {
        let threadDictionary = Thread.current.threadDictionary
        let storageKey = "com.swiftcommons.formattercache.storage"
        let storage: Storage
        if let cached = threadDictionary[storageKey] as? Storage {
            storage = cached
        } else {
            storage = Storage()
            threadDictionary[storageKey] = storage
        }
        let entryKey = EntryKey(
            formatterType: ObjectIdentifier(F.self),
            keyType: ObjectIdentifier(Key.self),
            configuration: AnyHashable(key)
        )
        if let cached = storage.formatters[entryKey] as? F {
            return cached
        }
        let formatter = make()
        storage.formatters[entryKey] = formatter
        // Fires once per unique (formatter type, key type, configuration, thread) — not per
        // format call — so this stays informative without becoming hot-path noise.
        logger.debugPublic(
            "Cache miss, configuring formatter | formatterType=\(String(describing: F.self)) "
                + "keyType=\(String(describing: Key.self))"
        )
        return formatter
    }
}
