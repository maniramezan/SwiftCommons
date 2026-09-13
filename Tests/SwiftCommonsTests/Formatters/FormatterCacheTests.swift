import Foundation
import Testing

@testable import SwiftCommons

@Suite("FormatterCache")
struct FormatterCacheTests {
    @Test
    func sameKeyReturnsSameInstance() {
        let firstFormatter = FormatterCache.formatter(for: "test.same") { NumberFormatter() }
        let secondFormatter = FormatterCache.formatter(for: "test.same") { NumberFormatter() }
        #expect(firstFormatter === secondFormatter)
    }

    @Test
    func differentKeysReturnDifferentInstances() {
        let formatterA = FormatterCache.formatter(for: "test.a") { NumberFormatter() }
        let formatterB = FormatterCache.formatter(for: "test.b") { NumberFormatter() }
        #expect(formatterA !== formatterB)
    }

    @Test
    func doesNotCallMakeOnCacheHit() {
        var callCount = 0
        _ = FormatterCache.formatter(for: "test.hitCount") {
            callCount += 1
            return NumberFormatter()
        }
        _ = FormatterCache.formatter(for: "test.hitCount") {
            callCount += 1
            return NumberFormatter()
        }
        #expect(callCount == 1)
    }

    @Test
    func sameKeyDifferentFormatterTypesDoNotCollide() {
        // The formatter type is folded into the storage key, so a `NumberFormatter` request and
        // a `DateFormatter` request sharing the string "test.shared" must not read back each
        // other's cached instance (which would otherwise crash the forced cast in `formatter`).
        let numberFormatter: NumberFormatter = FormatterCache.formatter(for: "test.shared") {
            NumberFormatter()
        }
        let dateFormatter: DateFormatter = FormatterCache.formatter(for: "test.shared") {
            DateFormatter()
        }
        #expect(type(of: numberFormatter) == NumberFormatter.self)
        #expect(type(of: dateFormatter) == DateFormatter.self)
    }

    @Test
    func separateThreadsHaveSeparateInstances() {
        let key = "test.thread.\(UUID().uuidString)"
        let formatter: NumberFormatter = FormatterCache.formatter(for: key) { NumberFormatter() }
        let identity = ObjectIdentifier(formatter)
        let finished = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            let other: NumberFormatter = FormatterCache.formatter(for: key) { NumberFormatter() }
            #expect(ObjectIdentifier(other) != identity)
            #expect(other === FormatterCache.formatter(for: key) { NumberFormatter() })
            finished.signal()
        }
        #expect(finished.wait(timeout: .now() + 5) == .success)
        withExtendedLifetime(formatter) {}
    }

    @Test
    func structuredKeysCompareFieldsRatherThanJoinedStrings() {
        struct Key: Hashable {
            let first: String
            let second: String

            func hash(into hasher: inout Hasher) {
                // Force a hash collision to verify dictionary equality still distinguishes keys.
                hasher.combine(0)
            }
        }
        let first: NumberFormatter = FormatterCache.formatter(
            for: Key(first: "a|b", second: "c")
        ) { NumberFormatter() }
        let second: NumberFormatter = FormatterCache.formatter(
            for: Key(first: "a", second: "b|c")
        ) { NumberFormatter() }
        let repeated: NumberFormatter = FormatterCache.formatter(
            for: Key(first: "a|b", second: "c")
        ) {
            Issue.record("Equal typed keys should reuse the formatter")
            return NumberFormatter()
        }
        #expect(first !== second)
        #expect(first === repeated)
    }

    @Test
    func keyTypesHaveIndependentNamespaces() {
        // AnyHashable considers these numeric values equal; their concrete types differ.
        let signed: NumberFormatter = FormatterCache.formatter(for: Int(42)) { NumberFormatter() }
        let unsigned: NumberFormatter = FormatterCache.formatter(for: UInt(42)) {
            NumberFormatter()
        }
        #expect(signed !== unsigned)
        #expect(signed === FormatterCache.formatter(for: Int(42)) { NumberFormatter() })
    }

    @Test
    func builtInDateKindsHaveDistinctKeys() {
        let locale = Locale(identifier: "en_US")
        let timeZone = TimeZone.gmt
        let pattern = DateFormatter.CacheKey.date(
            format: .pattern("yMMMMd"), calendar: nil, locale: locale, timeZone: timeZone)
        let template = DateFormatter.CacheKey.date(
            format: .template("yMMMMd"), calendar: nil, locale: locale, timeZone: timeZone)
        let first: DateFormatter = FormatterCache.formatter(for: pattern) { DateFormatter() }
        let second: DateFormatter = FormatterCache.formatter(for: template) { DateFormatter() }
        #expect(first !== second)
        #expect(first === FormatterCache.formatter(for: pattern) { DateFormatter() })
    }

}
