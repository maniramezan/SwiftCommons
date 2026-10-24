import SwiftCommons
import SwiftCommonsTestSupport
import Testing

@Suite("withTimeout", .timeLimit(.minutes(1)))
struct TimeoutTests {
    private enum OperationError: Error, Equatable {
        case failed
    }

    @Test func returnsOperationValueAndCancelsTimer() async throws {
        let timerClock = ManualClock()
        let operationClock = ManualClock()
        let task = Task {
            try await withTimeout(.seconds(10), clock: timerClock) {
                try await operationClock.sleep(for: .seconds(1))
                return "complete"
            }
        }
        defer { task.cancel() }
        try #require(await timerClock.waitForSleepCount(1))
        try #require(await operationClock.waitForSleepCount(1))
        await operationClock.advance(by: .seconds(1))

        #expect(try await task.value == "complete")
        #expect(await timerClock.waiterCount == 0)
    }

    @Test func timeoutCancelsOperationAndWaitsForCleanup() async throws {
        let timerClock = ManualClock()
        let operationClock = ManualClock()
        try await confirmation { cancelled in
            let task = Task {
                try await withTimeout(.seconds(5), clock: timerClock) {
                    do {
                        try await operationClock.sleep(for: .seconds(100))
                    } catch is CancellationError {
                        cancelled()
                        throw CancellationError()
                    }
                    return 42
                }
            }
            defer { task.cancel() }
            try #require(await timerClock.waitForSleepCount(1))
            try #require(await operationClock.waitForSleepCount(1))
            await timerClock.advance(by: .seconds(5))
            await #expect(throws: TimeoutError()) { try await task.value }
            #expect(await operationClock.waiterCount == 0)
        }
    }

    @Test func preservesOperationErrorAndCancelsTimer() async throws {
        let timerClock = ManualClock()
        let operationClock = ManualClock()
        let task = Task {
            try await withTimeout(.seconds(10), clock: timerClock) {
                try await operationClock.sleep(for: .seconds(1))
                throw OperationError.failed
            }
        }
        defer { task.cancel() }
        try #require(await timerClock.waitForSleepCount(1))
        try #require(await operationClock.waitForSleepCount(1))
        await operationClock.advance(by: .seconds(1))

        await #expect(throws: OperationError.failed) { try await task.value }
        #expect(await timerClock.waiterCount == 0)
    }

    @Test func parentCancellationIsNotATimeoutEvenIfOperationReturnsAValue() async throws {
        let timerClock = ManualClock()
        let operationClock = ManualClock()
        let task = Task {
            try await withTimeout(.seconds(10), clock: timerClock) {
                try? await operationClock.sleep(for: .seconds(100))
                return 42
            }
        }
        defer { task.cancel() }
        try #require(await timerClock.waitForSleepCount(1))
        try #require(await operationClock.waitForSleepCount(1))
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await timerClock.waiterCount == 0)
        #expect(await operationClock.waiterCount == 0)
    }

    @Test(arguments: [Duration.zero, .seconds(-1)])
    func nonpositiveDurationDoesNotStartOperation(duration: Duration) async {
        await confirmation(expectedCount: 0) { started in
            _ = await #expect(throws: TimeoutError()) {
                try await withTimeout(duration) {
                    started()
                    return 42
                }
            }
        }
    }

    @Test func optionalNilIsAnOperationResult() async throws {
        let value: Int? = try await withTimeout(.seconds(10)) { nil }
        #expect(value == nil)
    }

    @Test func alreadyCancelledParentTakesPrecedenceOverImmediateTimeout() async {
        let cancellationClock = ManualClock()
        await confirmation(expectedCount: 0) { started in
            let task = Task {
                try? await cancellationClock.sleep(for: .seconds(1))
                return try await withTimeout(.zero) {
                    started()
                    return 42
                }
            }
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }

    @Test func propagatesClockFailures() async {
        struct FailingClock: DelayClock {
            func sleep(for duration: Duration) async throws { throw OperationError.failed }
        }
        let operationClock = ManualClock()
        await #expect(throws: OperationError.failed) {
            try await withTimeout(.seconds(10), clock: FailingClock()) {
                try await operationClock.sleep(for: .seconds(100))
                return 42
            }
        }
        #expect(await operationClock.waiterCount == 0)
    }
}
