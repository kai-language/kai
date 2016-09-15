
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

  @discardableResult
  mutating func pop() -> Element {
    guard !buffer.isEmpty else { return buffer.removeFirst() }

    guard let element = iterator.next() else { fatalError("Scanner Exhuasted") }
    return element
  }
}
