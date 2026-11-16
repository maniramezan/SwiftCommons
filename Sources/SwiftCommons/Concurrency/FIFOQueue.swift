/// A first-in, first-out queue with amortized O(1) enqueue and dequeue.
///
/// `Array.removeFirst()` shifts every remaining element, so draining `n` waiters one at a time
/// is O(n²). This queue advances a head index instead and compacts the backing storage once
/// the consumed prefix reaches half of it.
struct FIFOQueue<Element> {
    private var storage: [Element?] = []
    private var head = 0

    /// The number of queued elements.
    var count: Int { storage.count - head }

    /// Whether the queue holds no elements.
    var isEmpty: Bool { head == storage.count }

    /// Adds `element` to the back of the queue.
    mutating func enqueue(_ element: Element) {
        storage.append(element)
    }

    /// Removes and returns the first element matching `predicate`, or `nil` if none matches.
    ///
    /// O(n); meant for the rare cancellation path, not the hot path.
    mutating func removeFirst(where predicate: (Element) -> Bool) -> Element? {
        guard let index = storage[head...].firstIndex(where: { $0.map(predicate) ?? false })
        else { return nil }
        let element = storage.remove(at: index)
        if head == storage.count {
            storage.removeAll(keepingCapacity: true)
            head = 0
        }
        return element
    }

    /// Removes and returns the element at the front, or `nil` when the queue is empty.
    mutating func dequeue() -> Element? {
        guard head < storage.count else { return nil }
        let element = storage[head]
        storage[head] = nil
        head += 1
        if head == storage.count {
            storage.removeAll(keepingCapacity: true)
            head = 0
        } else if head >= storage.count / 2 {
            storage.removeFirst(head)
            head = 0
        }
        return element
    }
}
