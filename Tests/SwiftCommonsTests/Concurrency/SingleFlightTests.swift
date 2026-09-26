import Foundation
import Testing

@testable import SwiftCommons

@Suite("SingleFlight")
struct SingleFlightTests {
    private struct FetchError: Error, Equatable {}

    @Test
    func concurrentCallersForOneKeyRunTheOperationOnce() async throws {
        let singleFlight = SingleFlight<String, Int>()
        let invocations = Counter()
        let gate = Gate()

        let callers = (0..<5).map { _ in
            Task {
                try await singleFlight.value(for: "profile") {
                    await invocations.increment()
                    await gate.wait()
                    return 42
                }
            }
        }
        await waitUntil { await singleFlight.callerCount(for: "profile") == 5 }
        await gate.open()

        for caller in callers {
            #expect(try await caller.value == 42)
        }
        #expect(await invocations.value == 1)
        #expect(await singleFlight.callerCount(for: "profile") == 0)
    }

    @Test
    func errorReachesEveryWaiter() async {
        let singleFlight = SingleFlight<String, Int>()
        let invocations = Counter()
        let gate = Gate()

        let callers = (0..<3).map { _ in
            Task {
                try await singleFlight.value(for: "profile") {
                    await invocations.increment()
                    await gate.wait()
                    throw FetchError()
                }
            }
        }
        await waitUntil { await singleFlight.callerCount(for: "profile") == 3 }
        await gate.open()

        for caller in callers {
            await #expect(throws: FetchError.self) { try await caller.value }
        }
        #expect(await invocations.value == 1)
    }

    @Test
    func finishedFlightIsNotCached() async throws {
        let singleFlight = SingleFlight<String, Int>()
        let invocations = Counter()

        let first = try await singleFlight.value(for: "profile") { await invocations.increment() }
        let second = try await singleFlight.value(for: "profile") { await invocations.increment() }

        #expect(first == 1)
        #expect(second == 2)
    }

    @Test
    func failedFlightIsNotCached() async throws {
        let singleFlight = SingleFlight<String, Int>()

        await #expect(throws: FetchError.self) {
            try await singleFlight.value(for: "profile") { throw FetchError() }
        }
        let value = try await singleFlight.value(for: "profile") { 7 }

        #expect(value == 7)
    }

    @Test
    func differentKeysRunConcurrently() async throws {
        let singleFlight = SingleFlight<String, String>()
        let invocations = Counter()
        let gate = Gate()

        let first = Task {
            try await singleFlight.value(for: "a") {
                await invocations.increment()
                await gate.wait()
                return "a"
            }
        }
        let second = Task {
            try await singleFlight.value(for: "b") {
                await invocations.increment()
                await gate.wait()
                return "b"
            }
        }
        await waitUntil { await invocations.value == 2 }
        await gate.open()

        #expect(try await first.value == "a")
        #expect(try await second.value == "b")
    }

    @Test
    func cancelStartsAFreshFlightAndDiscardsTheInvalidatedResult() async throws {
        let singleFlight = SingleFlight<String, Int>()
        let invocations = Counter()
        let gate = Gate()

        // The gate ignores cancellation, so the cancelled operation still returns a value.
        let staleCaller = Task {
            try await singleFlight.value(for: "profile") {
                let invocation = await invocations.increment()
                await gate.wait()
                return invocation
            }
        }
        await waitUntil { await invocations.value == 1 }

        await singleFlight.cancel("profile")
        #expect(await singleFlight.callerCount(for: "profile") == 0)

        let freshCaller = Task {
            try await singleFlight.value(for: "profile") {
                let invocation = await invocations.increment()
                await gate.wait()
                return invocation
            }
        }
        await waitUntil { await invocations.value == 2 }
        await gate.open()

        await #expect(throws: CancellationError.self) { try await staleCaller.value }
        #expect(try await freshCaller.value == 2)
    }

    @Test
    func cancelCancelsTheOperationTask() async {
        let singleFlight = SingleFlight<String, Int>()
        let observedCancellation = Flag()
        let gate = Gate()

        let caller = Task {
            try await singleFlight.value(for: "profile") {
                await gate.wait()
                await observedCancellation.set(Task.isCancelled)
                return 1
            }
        }
        await waitUntil { await singleFlight.callerCount(for: "profile") == 1 }

        await singleFlight.cancel("profile")
        await gate.open()

        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await observedCancellation.value)
    }

    @Test
    func cancelAllCancelsEveryKey() async {
        let singleFlight = SingleFlight<String, Int>()
        let gate = Gate()

        let callers = ["a", "b"].map { key in
            Task {
                try await singleFlight.value(for: key) {
                    await gate.wait()
                    return 1
                }
            }
        }
        await waitUntil { await singleFlight.callerCount(for: "a") == 1 }
        await waitUntil { await singleFlight.callerCount(for: "b") == 1 }

        await singleFlight.cancelAll()
        await gate.open()

        for caller in callers {
            await #expect(throws: CancellationError.self) { try await caller.value }
        }
    }

    @Test
    func cancelledCallerDoesNotCancelSharedWork() async throws {
        let singleFlight = SingleFlight<String, Int>()
        let gate = Gate()
        let operation: @Sendable () async throws -> Int = {
            await gate.wait()
            return 42
        }

        let cancelledCaller = Task {
            try await singleFlight.value(for: "profile", operation: operation)
        }
        let otherCaller = Task {
            try await singleFlight.value(for: "profile", operation: operation)
        }
        await waitUntil { await singleFlight.callerCount(for: "profile") == 2 }

        cancelledCaller.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await cancelledCaller.value }
        #expect(try await otherCaller.value == 42)
    }

    @Test
    func alreadyCancelledCallerDoesNotStartAFlight() async {
        let singleFlight = SingleFlight<String, Int>()
        let invocations = Counter()

        let caller = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await singleFlight.value(for: "profile") { await invocations.increment() }
        }

        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await invocations.value == 0)
    }

    // MARK: - Helpers

    private func waitUntil(_ condition: @Sendable () async -> Bool) async {
        while await !condition() {
            await Task.yield()
        }
    }

    private actor Counter {
        private(set) var value = 0

        @discardableResult
        func increment() -> Int {
            value += 1
            return value
        }
    }

    private actor Flag {
        private(set) var value = false

        func set(_ newValue: Bool) {
            value = newValue
        }
    }

    /// Suspends callers until opened. Deliberately ignores task cancellation.
    private actor Gate {
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func open() {
            isOpen = true
            for waiter in waiters {
                waiter.resume()
            }
            waiters.removeAll()
        }
    }
}
