import Foundation
import Testing

@testable import SwiftCommons

@Suite("FormatterCache")
struct FormatterCacheTests {
    @Test
    func sameKeyReturnsSameInstance() {
        let f1 = FormatterCache.formatter(for: "test.same") { NumberFormatter() }
        let f2 = FormatterCache.formatter(for: "test.same") { NumberFormatter() }
        #expect(f1 === f2)
    }

    @Test
    func differentKeysReturnDifferentInstances() {
        let f1 = FormatterCache.formatter(for: "test.a") { NumberFormatter() }
        let f2 = FormatterCache.formatter(for: "test.b") { NumberFormatter() }
        #expect(f1 !== f2)
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

}
