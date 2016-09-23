
struct ByteScanner {

  var pointer: UnsafePointer<Byte>
  var buffer: UnsafeBufferPointer<Byte>
  let bufferCopy: [Byte]
}

extension ByteScanner {

  init(_ data: [Byte]) {
    self.bufferCopy = data
    self.buffer = bufferCopy.withUnsafeBufferPointer { $0 }

    self.pointer = buffer.baseAddress!
  }
}

extension ByteScanner {

  func peek(aheadBy n: Int = 0) -> Byte? {
    guard pointer.advanced(by: n) < buffer.endAddress else { return nil }
    return pointer.advanced(by: n).pointee
  }

  /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
  @discardableResult
  mutating func pop() -> Byte {
    assert(pointer != buffer.endAddress)
    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }

  /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
  @discardableResult
  mutating func attemptPop() throws -> Byte {
    guard pointer < buffer.endAddress else { throw Error.Reason.endOfStream }
    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }
}

extension ByteScanner {

  struct Error: Swift.Error {
    let position: UInt
    let reason: Reason

    enum Reason: Swift.Error {
      case emptyInput
      case endOfStream
      case unexpected(at: UInt)
    }
  }
}

extension UnsafeBufferPointer {

  fileprivate var endAddress: UnsafePointer<Element> {

    return baseAddress!.advanced(by: endIndex)
  }
}
