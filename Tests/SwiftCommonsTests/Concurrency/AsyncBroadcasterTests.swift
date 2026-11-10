import Foundation
import Synchronization
import Testing

@testable import SwiftCommons

@Suite("AsyncBroadcaster")
struct AsyncBroadcasterTests {
    @Test
    func deliversEachValueToEveryStream() async {
        let broadcaster = AsyncBroadcaster<Int>()
        let firstStream = broadcaster.makeStream()
        let secondStream = broadcaster.makeStream()

        broadcaster.yield(1)
        broadcaster.yield(2)
        broadcaster.finish()

        #expect(await collect(firstStream) == [1, 2])
        #expect(await collect(secondStream) == [1, 2])
    }

    @Test
    func streamOnlySeesValuesYieldedAfterItWasCreatedByDefault() async {
        let broadcaster = AsyncBroadcaster<Int>()
        broadcaster.yield(1)
        let stream = broadcaster.makeStream()
        broadcaster.yield(2)
        broadcaster.finish()

        #expect(await collect(stream) == [2])
    }

    @Test
    func replaysLatestValueToNewStreams() async {
        let broadcaster = AsyncBroadcaster<Int>(replaysLatest: true)
        let earlyStream = broadcaster.makeStream()
        broadcaster.yield(1)
        broadcaster.yield(2)
        let lateStream = broadcaster.makeStream()
        broadcaster.yield(3)
        broadcaster.finish()

        #expect(await collect(earlyStream) == [1, 2, 3])
        #expect(await collect(lateStream) == [2, 3])
    }

    @Test
    func replayingBroadcasterWithNothingYieldedStartsEmpty() async {
        let broadcaster = AsyncBroadcaster<Int>(replaysLatest: true)
        let stream = broadcaster.makeStream()
        broadcaster.finish()

        #expect(await collect(stream) == [])
    }

    @Test
    func initialValueIsReplayedUntilReplaced() async {
        let broadcaster = AsyncBroadcaster(initialValue: "unknown")
        let firstStream = broadcaster.makeStream()
        broadcaster.yield("reachable")
        let secondStream = broadcaster.makeStream()
        broadcaster.finish()

        #expect(await collect(firstStream) == ["unknown", "reachable"])
        #expect(await collect(secondStream) == ["reachable"])
    }

    @Test
    func finishEndsAllStreamsAndClearsSubscribers() async {
        let broadcaster = AsyncBroadcaster<Int>()
        let streams = (0..<3).map { _ in broadcaster.makeStream() }
        #expect(broadcaster.subscriberCount == 3)

        broadcaster.finish()

        #expect(broadcaster.subscriberCount == 0)
        for stream in streams {
            #expect(await collect(stream) == [])
        }
    }

    @Test
    func streamCreatedAfterFinishFinishesImmediately() async {
        let broadcaster = AsyncBroadcaster<Int>(replaysLatest: true)
        broadcaster.yield(1)
        broadcaster.finish()

        let stream = broadcaster.makeStream()

        #expect(broadcaster.subscriberCount == 0)
        #expect(await collect(stream) == [])
    }

    @Test
    func yieldAfterFinishIsIgnored() async {
        let broadcaster = AsyncBroadcaster<Int>()
        let stream = broadcaster.makeStream()
        broadcaster.yield(1)
        broadcaster.finish()
        broadcaster.yield(2)

        #expect(await collect(stream) == [1])
    }

    @Test
    func terminatedConsumerIsRemoved() async {
        let broadcaster = AsyncBroadcaster<Int>()
        let stream = broadcaster.makeStream()
        let (received, receivedContinuation) = AsyncStream.makeStream(of: Int.self)
        let consumer = Task {
            for await value in stream {
                receivedContinuation.yield(value)
            }
        }

        broadcaster.yield(1)
        var receivedIterator = received.makeAsyncIterator()
        #expect(await receivedIterator.next() == 1)
        #expect(broadcaster.subscriberCount == 1)

        consumer.cancel()
        await consumer.value

        #expect(broadcaster.subscriberCount == 0)
    }

    @Test
    func droppedStreamIsRemoved() {
        let broadcaster = AsyncBroadcaster<Int>()
        do {
            _ = broadcaster.makeStream()
        }

        #expect(broadcaster.subscriberCount == 0)
    }

    /// Regression test for registering and unregistering through separate unstructured tasks,
    /// where an immediate cancellation could run the unregistration first and leak the
    /// continuation.
    @Test
    func consumerCancelledImmediatelyAfterSubscribingDoesNotLeak() async {
        let broadcaster = AsyncBroadcaster<Int>(replaysLatest: true)
        broadcaster.yield(0)

        for _ in 0..<200 {
            let stream = broadcaster.makeStream()
            let consumer = Task {
                for await _ in stream {}
            }
            consumer.cancel()
            await consumer.value
        }

        #expect(broadcaster.subscriberCount == 0)
    }

    @Test
    func deallocatingBroadcasterFinishesStreams() async {
        var broadcaster: AsyncBroadcaster<Int>? = AsyncBroadcaster<Int>()
        let stream = broadcaster?.makeStream()
        broadcaster?.yield(1)
        broadcaster = nil

        #expect(await collect(stream) == [1])
    }

    @Test
    func concurrentYieldsReachEveryStream() async {
        let broadcaster = AsyncBroadcaster<Int>()
        let streams = (0..<4).map { _ in broadcaster.makeStream() }

        await withTaskGroup(of: Void.self) { group in
            for value in 0..<100 {
                group.addTask { broadcaster.yield(value) }
            }
        }
        broadcaster.finish()

        for stream in streams {
            #expect(await collect(stream).sorted() == Array(0..<100))
        }
    }

    @Test
    func cancellingAConsumerWhileAValueIsYieldedDoesNotDeadlock() async throws {
        // Cancelling a consumer runs its stream's `onTermination` while the runtime holds the
        // consumer task's status lock, and yielding to a waiting consumer takes that same lock.
        // Each iteration parks a consumer in `next()`, then yields from another thread while
        // cancelling it. The race runs in an unstructured task so a deadlock fails this test at the
        // deadline instead of hanging the whole suite.
        let progress = Mutex(0)
        let iterations = 2_000
        let race = Task.detached {
            for value in 0..<iterations {
                let broadcaster = AsyncBroadcaster<Int>()
                let stream = broadcaster.makeStream()
                let consumer = Task {
                    var iterator = stream.makeAsyncIterator()
                    _ = await iterator.next()
                }
                await Task.yield()
                DispatchQueue.global().async { broadcaster.yield(value) }
                consumer.cancel()
                await consumer.value
                progress.withLock { $0 += 1 }
            }
        }

        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while progress.withLock({ $0 }) < iterations, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        let completed = progress.withLock { $0 }
        #expect(
            completed == iterations, "Deadlocked after \(completed) of \(iterations) iterations")
        if completed == iterations {
            await race.value
        }
    }

    private func collect<Element>(_ stream: AsyncStream<Element>?) async -> [Element] {
        guard let stream else { return [] }
        var values: [Element] = []
        for await value in stream {
            values.append(value)
        }
        return values
    }
}
