
/// This scanner class allows arbitrary lookahead
struct BufferedScanner<Element> {

  var iterator: AnyIterator<Element>

  /// Buffer is always the tokens that follow last `pop` the number depends on how far we have peeked
  var buffer: [Element] = []

  init(_ iterator: AnyIterator<Element>) {

    self.buffer = []
    self.iterator = iterator
  }

  init<I: IteratorProtocol>(_ iterator: I) where I.Element == Element {

    self.buffer = []
    self.iterator = AnyIterator(iterator)
  }
}

extension BufferedScanner {

  mutating func peek(aheadBy n: Int = 0) -> Element? {
    guard buffer.count <= n else {
      return buffer[n]
    }

    guard let element = iterator.next() else { return nil }

    buffer.append(element)
    return buffer.last
  }

  /// - Precondition: Call to peek first to ensure the underlying sequence has not been exhausted
  @discardableResult
  mutating func pop() -> Element {

    switch buffer.isEmpty {
    case true:  return iterator.next()!
    case false: return buffer.removeFirst()
    }
  }
}
