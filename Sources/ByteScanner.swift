
struct ByteScanner {

  typealias Byte = UTF8.CodeUnit

  var pointer: UnsafePointer<Byte>
  var buffer: UnsafeBufferPointer<Byte>
  let bufferCopy: [Byte]
}

extension ByteScanner {

  init(_ data: [Byte]) throws {
    self.bufferCopy = data
    self.buffer = bufferCopy.withUnsafeBufferPointer { $0 }

    guard let pointer = buffer.baseAddress, buffer.endAddress != buffer.baseAddress else {
      throw Error.Reason.emptyInput
    }

    self.pointer = pointer
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

  /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
  @discardableResult
  mutating func pop(until terminator: Byte) -> [Byte] {
    var seen: [Byte] = []
    repeat {

      guard let char = peek() else { return seen }
      if char == terminator { return seen }

      seen.append(pop())
    } while true
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
      case searchFailed(at: UInt, wanted: [Byte])
    }
  }
}

extension UnsafeBufferPointer {

  fileprivate var endAddress: UnsafePointer<Element> {

    return baseAddress!.advanced(by: endIndex)
  }
}

