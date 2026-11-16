import Foundation
import Testing

@testable import SwiftCommons

@Suite("AsyncSemaphore")
struct AsyncSemaphoreTests {
    private actor Counter {
        private(set) var concurrent = 0
        private(set) var maxConcurrent = 0

        func enter() {
            concurrent += 1
            maxConcurrent = max(maxConcurrent, concurrent)
        }

        func exit() {
            concurrent -= 1
        }
    }

    @Test
    func limitsConcurrentHoldersToValue() async {
        let semaphore = AsyncSemaphore(value: 2)
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await semaphore.wait()
                    await counter.enter()
                    await Task.yield()
                    await counter.exit()
                    await semaphore.signal()
                }
            }
        }

        #expect(await counter.maxConcurrent <= 2)
    }

    @Test
    func withPermitReleasesAfterSuccess() async throws {
        let semaphore = AsyncSemaphore(value: 1)

        let result = try await semaphore.withPermit {
            "done"
        }
        #expect(result == "done")

        // The permit should be available again immediately.
        let secondResult = try await semaphore.withPermit {
            "done again"
        }
        #expect(secondResult == "done again")
    }

    @Test
    func withPermitReleasesAfterThrow() async {
        struct DummyError: Error {}
        let semaphore = AsyncSemaphore(value: 1)

        await #expect(throws: DummyError.self) {
            try await semaphore.withPermit {
                throw DummyError()
            }
        }

        // The permit should still be released despite the throw.
        let result = try? await semaphore.withPermit { "ok" }
        #expect(result == "ok")
    }

    @Test
    func secondWaiterSuspendsUntilSignal() async {
        let semaphore = AsyncSemaphore(value: 1)
        await semaphore.wait()

        let waiter = Task {
            await semaphore.wait()
            return "acquired"
        }

        await Task.yield()
        #expect(waiter.isCancelled == false)

        await semaphore.signal()
        #expect(await waiter.value == "acquired")
    }

    /// Records the order in which waiters acquire a permit.
    private actor AcquisitionLog {
        private(set) var order: [Int] = []
        func record(_ index: Int) { order.append(index) }
    }

    @Test
    func resumesManyWaitersInArrivalOrder() async {
        let semaphore = AsyncSemaphore(value: 1)
        let log = AcquisitionLog()
        let waiterCount = 500
        await semaphore.wait()

        var waiters: [Task<Void, Never>] = []
        for index in 0..<waiterCount {
            waiters.append(
                Task {
                    await semaphore.wait()
                    await log.record(index)
                    await semaphore.signal()
                })
            // Let each waiter enqueue before the next starts so arrival order is deterministic.
            while await semaphore.waiterCount <= index { await Task.yield() }
        }

        await semaphore.signal()
        for waiter in waiters { await waiter.value }

        #expect(await log.order == Array(0..<waiterCount))
    }

    @Test
    func cancelledCancellableWaiterLeavesTheQueueWithoutTakingAPermit() async {
        let semaphore = AsyncSemaphore(value: 1)
        await semaphore.wait()
        let waiter = Task { try await semaphore.waitCancellable() }
        while await semaphore.waiterCount < 1 { await Task.yield() }

        waiter.cancel()

        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(await semaphore.waiterCount == 0)
        await semaphore.signal()
        // The permit is back: the cancelled waiter did not consume it.
        #expect((try? await semaphore.waitCancellable()) != nil)
    }

    @Test
    func alreadyCancelledTaskThrowsWithoutTakingAPermit() async {
        let semaphore = AsyncSemaphore(value: 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await semaphore.waitCancellable()
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        await semaphore.wait()
    }

    @Test
    func withPermitCancellableRunsTheOperationAndReleases() async throws {
        let semaphore = AsyncSemaphore(value: 1)

        let value = try await semaphore.withPermitCancellable { 42 }

        #expect(value == 42)
        await semaphore.wait()
    }

    /// Not `Sendable`: `withPermit` must accept a body that captures it.
    private final class Tally {
        var value = 0
    }

    @Test
    func withPermitAcceptsAnOperationCapturingNonSendableState() async {
        let semaphore = AsyncSemaphore(value: 1)
        let tally = Tally()

        await semaphore.withPermit { tally.value += 1 }

        #expect(tally.value == 1)
    }
}
