
/*
 First-in first-out queue (FIFO)
 New elements are added to the end of the queue. Dequeuing pulls elements from
 the front of the queue.
 Enqueuing is an O(1) operation, dequeuing is O(n). Note: If the queue had been
 implemented with a linked list, then both would be O(1).
 */
struct Queue<T> {
    fileprivate var array = [T]()

    var count: Int {
        return array.count
    }

    var isEmpty: Bool {
        return array.isEmpty
    }

    mutating func enqueue(_ element: T) {
        array.append(element)
    }

    mutating func dequeue() -> T? {
        if isEmpty {
            return nil
        } else {
            return array.removeFirst()
        }
    }
    
    var front: T? {
        return array.first
    }
}
