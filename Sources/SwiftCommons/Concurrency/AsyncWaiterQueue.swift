/// The FIFO queue of suspended acquirers shared by ``AsyncLock`` and ``AsyncSemaphore``.
///
/// Plain waiters can't be removed once queued. Cancellable waiters carry an id so a cancelled
/// task can leave the queue and be resumed with `CancellationError` instead of waiting for a
/// permit it no longer wants.
struct AsyncWaiterQueue {
    private enum Continuation {
        case uninterruptible(CheckedContinuation<Void, Never>)
        case cancellable(CheckedContinuation<Void, any Error>)
    }

    private struct Waiter {
        let id: Int
        let continuation: Continuation
    }

    private var queue = FIFOQueue<Waiter>()
    private var nextID = 0

    /// The number of suspended waiters.
    var count: Int { queue.count }

    /// Reserves an id for a cancellable waiter before it suspends.
    mutating func makeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    /// Queues a waiter that stays queued until it is resumed.
    mutating func enqueue(_ continuation: CheckedContinuation<Void, Never>) {
        queue.enqueue(Waiter(id: makeID(), continuation: .uninterruptible(continuation)))
    }

    /// Queues a waiter that ``cancel(id:)`` can remove.
    mutating func enqueue(_ continuation: CheckedContinuation<Void, any Error>, id: Int) {
        queue.enqueue(Waiter(id: id, continuation: .cancellable(continuation)))
    }

    /// Resumes the waiter at the front. Returns `false` when nobody is waiting.
    mutating func resumeNext() -> Bool {
        guard let waiter = queue.dequeue() else { return false }
        switch waiter.continuation {
        case .uninterruptible(let continuation): continuation.resume()
        case .cancellable(let continuation): continuation.resume()
        }
        return true
    }

    /// Removes the cancellable waiter `id`, if still queued, and resumes it with
    /// `CancellationError`. Does nothing if it was already resumed.
    mutating func cancel(id: Int) {
        guard let waiter = queue.removeFirst(where: { $0.id == id }) else { return }
        if case .cancellable(let continuation) = waiter.continuation {
            continuation.resume(throwing: CancellationError())
        }
    }
}
