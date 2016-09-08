
struct Scanner<Element> {

  var pointer: UnsafePointer<Element>
  var elements: UnsafeBufferPointer<Element>
  // assuming you don't mutate no copy _should_ occur
  let elementsCopy: [Element]
}

extension Scanner {

  init(_ data: [Element]) {
    self.elementsCopy = data
    self.elements = elementsCopy.withUnsafeBufferPointer { $0 }

    self.pointer = elements.baseAddress!
  }
}

extension Scanner {

  func peek(aheadBy n: Int = 0) -> Element? {
    guard pointer.advanced(by: n) < elements.endAddress else { return nil }
    return pointer.advanced(by: n).pointee
  }

  /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
  @discardableResult
  mutating func pop() -> Element {
    assert(pointer != elements.endAddress)
    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }

  /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
  @discardableResult
  mutating func attemptPop() throws -> Element {
    guard pointer < elements.endAddress else { throw ScannerError.Reason.endOfStream }
    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }
}


struct ScannerError: Swift.Error {
  let position: UInt
  let reason: Reason

  enum Reason: Swift.Error {
    case endOfStream
  }
}

extension UnsafeBufferPointer {

  fileprivate var endAddress: UnsafePointer<Element> {

    return baseAddress!.advanced(by: endIndex)
  }
}
