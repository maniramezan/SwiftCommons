import Testing

@testable import SwiftCommons

@Suite("AsyncLock")
struct AsyncLockTests {
    /// A non-Sendable counter whose increments are only safe under the lock.
    private final class Counter: @unchecked Sendable {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    @Test
    func serializesConcurrentWorkAcrossAwaits() async {
        let lock = AsyncLock()
        let counter = Counter()
        let iterations = 1_000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await lock.lock()
                    let current = counter.value
                    // Force a suspension inside the critical section; without a
                    // real lock this is where interleaving would corrupt state.
                    await Task.yield()
                    counter.increment()
                    #expect(counter.value == current + 1)
                    await lock.unlock()
                }
            }
        }

        #expect(counter.value == iterations)
    }

    @Test
    func secondAcquirerWaitsUntilUnlock() async {
        let lock = AsyncLock()
        await lock.lock()

        let waiter = Task {
            await lock.lock()
            return "acquired"
        }

        // Give the waiter a chance to suspend, then confirm it hasn't acquired.
        await Task.yield()
        #expect(waiter.isCancelled == false)

        await lock.unlock()
        #expect(await waiter.value == "acquired")
        await lock.unlock()
    }

    private struct CriticalSectionError: Error {}

    @Test
    func withLockReturnsTheBodyResultAndReleases() async {
        let lock = AsyncLock()
        let value = await lock.withLock { 42 }
        #expect(value == 42)
        // Released: a second acquisition doesn't suspend forever.
        #expect(await lock.withLock { "again" } == "again")
    }

    @Test
    func withLockReleasesWhenTheBodyThrows() async {
        let lock = AsyncLock()
        await #expect(throws: CriticalSectionError.self) {
            try await lock.withLock { throw CriticalSectionError() }
        }
        #expect(await lock.withLock { "acquired after throw" } == "acquired after throw")
    }

    @Test
    func withLockSerializesOverlappingCriticalSections() async {
        actor Log {
            var entries: [String] = []
            func append(_ entry: String) { entries.append(entry) }
        }
        let lock = AsyncLock()
        let log = Log()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<5 {
                group.addTask {
                    await lock.withLock {
                        await log.append("start \(index)")
                        await Task.yield()
                        await log.append("end \(index)")
                    }
                }
            }
        }

        let entries = await log.entries
        #expect(entries.count == 10)
        for pairStart in stride(from: 0, to: entries.count, by: 2) {
            let startIndex = entries[pairStart].dropFirst("start ".count)
            #expect(entries[pairStart + 1] == "end \(startIndex)")
        }
    }
}
