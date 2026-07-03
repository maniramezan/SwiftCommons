import Foundation
import Testing

@testable import SwiftCommons

@Suite("withRetry")
struct WithRetryTests {
    private struct DummyError: Error, Equatable {
        let id: Int
    }

    @Test
    func returnsValueImmediatelyOnFirstSuccess() async throws {
        let callCount = Counter()
        let result = try await withRetry(attempts: 3) {
            await callCount.increment()
            return "ok"
        }
        #expect(result == "ok")
        #expect(await callCount.value == 1)
    }

    @Test
    func retriesUntilSuccess() async throws {
        let callCount = Counter()
        let result = try await withRetry(attempts: 3) {
            let count = await callCount.increment()
            if count < 3 {
                throw DummyError(id: count)
            }
            return count
        }
        #expect(result == 3)
        #expect(await callCount.value == 3)
    }

    @Test
    func throwsFinalErrorAfterExhaustingAttempts() async {
        let callCount = Counter()
        await #expect(throws: DummyError.self) {
            try await withRetry(attempts: 3) {
                let count = await callCount.increment()
                throw DummyError(id: count)
            }
        }
        #expect(await callCount.value == 3)
    }

    @Test
    func singleAttemptDoesNotRetry() async {
        let callCount = Counter()
        await #expect(throws: DummyError.self) {
            try await withRetry(attempts: 1) {
                await callCount.increment()
                throw DummyError(id: 0)
            }
        }
        #expect(await callCount.value == 1)
    }

    private actor Counter {
        private(set) var value = 0

        @discardableResult
        func increment() -> Int {
            value += 1
            return value
        }
    }
}
