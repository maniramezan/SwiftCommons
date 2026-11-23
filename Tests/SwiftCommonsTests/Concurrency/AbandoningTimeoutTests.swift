import SwiftCommons
import SwiftCommonsTestSupport
import Synchronization
import Testing

@Suite("withAbandoningTimeout", .timeLimit(.minutes(1)))
struct AbandoningTimeoutTests {
    private enum OperationError: Error, Equatable {
        case failed
    }

    /// An operation that ignores cancellation: it only finishes when ``release(_:)`` is called.
    private final class StubbornOperation: Sendable {
        private let waiter: Mutex<CheckedContinuation<Int, Never>?> = .init(nil)
        private let observedCancellation: Mutex<Bool?> = .init(nil)

        /// Whether the operation was cancelled when it finished, or `nil` while it is still running.
        var sawCancellation: Bool? { observedCancellation.withLock { $0 } }
        var isWaiting: Bool { waiter.withLock { $0 != nil } }

        func run() async -> Int {
            let value: Int = await withCheckedContinuation { continuation in
                waiter.withLock { $0 = continuation }
            }
            observedCancellation.withLock { $0 = Task.isCancelled }
            return value
        }

        func release(_ value: Int) {
            waiter.withLock { waiter in
                waiter?.resume(returning: value)
                waiter = nil
            }
        }
    }

    private static func eventually(_ condition: @Sendable () async -> Bool) async throws -> Bool {
        for _ in 0..<400 {
            if await condition() { return true }
            try await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    @Test func returnsTheOperationValueAndCancelsTheTimer() async throws {
        let timerClock = ManualClock()
        let operationClock = ManualClock()
        let task = Task {
            try await withAbandoningTimeout(.seconds(10), clock: timerClock) {
                try await operationClock.sleep(for: .seconds(1))
                return "complete"
            }
        }
        defer { task.cancel() }
        try #require(await timerClock.waitForSleepCount(1))
        try #require(await operationClock.waitForSleepCount(1))
        await operationClock.advance(by: .seconds(1))

        #expect(try await task.value == "complete")
        // The losing timer is cancelled asynchronously once the operation wins.
        #expect(try await Self.eventually { await timerClock.waiterCount == 0 })
    }

    @Test func preservesTheOperationError() async throws {
        let timerClock = ManualClock()
        let operationClock = ManualClock()
        let task = Task {
            try await withAbandoningTimeout(.seconds(10), clock: timerClock) {
                try await operationClock.sleep(for: .seconds(1))
                throw OperationError.failed
            }
        }
        defer { task.cancel() }
        try #require(await timerClock.waitForSleepCount(1))
        try #require(await operationClock.waitForSleepCount(1))
        await operationClock.advance(by: .seconds(1))

        await #expect(throws: OperationError.failed) { try await task.value }
    }

    @Test func timesOutWithoutWaitingForAnOperationThatIgnoresCancellation() async throws {
        let timerClock = ManualClock()
        let operation = StubbornOperation()
        let task = Task {
            try await withAbandoningTimeout(.seconds(5), clock: timerClock) {
                await operation.run()
            }
        }
        defer { task.cancel() }
        try #require(await timerClock.waitForSleepCount(1))
        await timerClock.advance(by: .seconds(5))

        await #expect(throws: TimeoutError()) { try await task.value }
        #expect(operation.isWaiting)

        // The abandoned operation was cancelled, and finishing it later changes nothing.
        operation.release(42)
        await #expect(throws: TimeoutError()) { try await task.value }
        #expect(try await Self.eventually { operation.sawCancellation != nil })
        #expect(operation.sawCancellation == true)
    }

    @Test func callerCancellationReturnsWithoutWaitingForTheOperation() async throws {
        let timerClock = ManualClock()
        let operation = StubbornOperation()
        let task = Task {
            try await withAbandoningTimeout(.seconds(5), clock: timerClock) {
                await operation.run()
            }
        }
        try #require(await timerClock.waitForSleepCount(1))

        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        operation.release(1)
    }

    @Test func aNonPositiveDurationNeverStartsTheOperation() async {
        let started: Mutex<Bool> = .init(false)

        await #expect(throws: TimeoutError()) {
            try await withAbandoningTimeout(.zero) {
                started.withLock { $0 = true }
                return 1
            }
        }
        #expect(!started.withLock { $0 })
    }
}
