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
}
