import Testing

@testable import SwiftCommons

@Suite("FIFOQueue")
struct FIFOQueueTests {
    @Test
    func dequeueOnAnEmptyQueueReturnsNil() {
        var queue = FIFOQueue<Int>()

        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.dequeue() == nil)
    }

    @Test
    func dequeuesInInsertionOrder() {
        var queue = FIFOQueue<Int>()
        for value in 0..<5 { queue.enqueue(value) }

        #expect(queue.count == 5)
        #expect((0..<5).map { _ in queue.dequeue() } == [0, 1, 2, 3, 4])
        #expect(queue.isEmpty)
    }

    @Test
    func keepsOrderAcrossCompactionWhileInterleavingEnqueues() {
        var queue = FIFOQueue<Int>()
        var expected: [Int] = []
        var actual: [Int] = []
        var next = 0

        for round in 0..<200 {
            for _ in 0..<(round % 7 + 1) {
                queue.enqueue(next)
                expected.append(next)
                next += 1
            }
            for _ in 0..<(round % 5 + 1) {
                if let value = queue.dequeue() { actual.append(value) }
            }
        }
        while let value = queue.dequeue() { actual.append(value) }

        #expect(actual == expected)
        #expect(queue.isEmpty)
    }

    @Test
    func isReusableAfterBeingDrained() {
        var queue = FIFOQueue<String>()
        queue.enqueue("first")
        #expect(queue.dequeue() == "first")

        queue.enqueue("second")

        #expect(queue.count == 1)
        #expect(queue.dequeue() == "second")
    }
}
