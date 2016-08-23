
struct ByteScanner {

  typealias Byte = UTF8.CodeUnit

  var bytes: AnyCollection<Byte>
  var index: UInt

  init<I: IteratorProtocol>(bytes: I) where I.Element == Byte {

    self.bytes = bytes
    self.bytes = bytes
  }

  mutating func match(_ string: String) throws {

    for expected in string.utf8 {
      guard let nextByte = bytes.next() else { throw Error.Reason.endOfStream }
      guard nextByte == expected else { throw Error.Reason.searchFailed(at: consumed, wanted: Array(string.utf8)) }

      consumed += 1
    }
  }
}

extension ByteScanner {

  mutating func consume(to terminator: Byte) -> [Byte]? {
    var byteBuffer: [Byte] = []

    while let byte = bytes.next() {

      if byte == terminator {

        return byteBuffer
      } else {

        byteBuffer.append(byte)
      }
    }

    guard !byteBuffer.isEmpty else { return nil }
    return byteBuffer
  }

  mutating func consume(to isTerminator: (Byte) -> Bool) -> [Byte]? {
    var byteBuffer: [Byte] = []

    while let byte = bytes.next() {

      if isTerminator(byte) {

        return byteBuffer
      } else {

        byteBuffer.append(byte)
      }
    }

    guard !byteBuffer.isEmpty else { return nil }
    return byteBuffer
  }
}

extension ByteScanner {

  mutating func skip(while testTrue: (Byte) -> Bool) throws {

    while let byte = bytes.next() {

      if testTrue(byte) { return }

      consumed += 1
    }

    throw Error.Reason.endOfStream
  }

  mutating func skip(until match: String) throws {

    let expectedBytes: [Byte] = Array(match.utf8)

    var nextIndexToMatch = expectedBytes.startIndex

    while let byte = bytes.next(), nextIndexToMatch != expectedBytes.endIndex {

      assert(nextIndexToMatch < expectedBytes.endIndex)

      if byte == expectedBytes[nextIndexToMatch] {

        nextIndexToMatch = expectedBytes.index(after: nextIndexToMatch)
      } else {

        nextIndexToMatch = expectedBytes.startIndex
      }

      consumed += 1
    }

    throw Error.Reason.searchFailed(at: consumed, wanted: expectedBytes)
  }
}

extension ByteScanner: IteratorProtocol, Sequence {

  mutating func next() -> Byte? {
    return bytes.next()
  }
}

extension ByteScanner {

  struct Error: Swift.Error {
    let position: UInt
    let reason: Reason

    enum Reason: Swift.Error {
      case endOfStream
      case unexpected(at: UInt)
      case searchFailed(at: UInt, wanted: [Byte])
    }
  }
}
