
// https://github.com/raywenderlich/swift-algorithm-club

/*
 Last-in first-out stack (LIFO)
 Push and pop are O(1) operations.
 */
struct Stack<Element> {
  private var array: [Element] = []

  var elements: [Element] {
    return array
  }

  var isEmpty: Bool {
    return array.isEmpty
  }

  var indices: CountableRange<Int> {
    return array.indices
  }

  var count: Int {
    return array.count
  }

  mutating func push(_ element: Element) {
    array.append(element)
  }

  @discardableResult
  mutating func pop() -> Element? {
    return array.popLast()
  }

  func peek() -> Element? {
    return array.last
  }

  mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
    self.array.removeAll(keepingCapacity: keepCapacity)
  }
}

extension Stack: Sequence {
  func makeIterator() -> AnyIterator<Element> {
    var curr = self
    return AnyIterator { _ -> Element? in
      return curr.pop()
    }
  }
}

extension Stack: ExpressibleByArrayLiteral {

  init(arrayLiteral elements: Element...) {

    self.init()
    elements.forEach { self.push($0) }
  }
}

