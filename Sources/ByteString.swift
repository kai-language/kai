
// http://stackoverflow.com/questions/9616296/whats-the-best-hash-for-utf-8-strings
func xorHash(_ bytes: [UInt8]) -> Int {

  return bytes.reduce(5381) { hash, byte in

    return ((hash << 5) &+ hash) ^ numericCast(byte)
  }
}

struct ByteString {

  typealias Byte = UInt8

  var bytes: [Byte]

  init(_ bytes: [Byte]) {

    self.bytes = bytes
  }

  /// append
  static func + (lhs: ByteString, rhs: ByteString) -> ByteString {

    return ByteString(lhs.bytes + rhs.bytes)
  }

  var hashValue: Int {

    return xorHash(bytes)
  }
}

extension ByteString: Equatable {

  static func == (lhs: ByteString, rhs: ByteString) -> Bool {
    return lhs.bytes == rhs.bytes
  }
}

extension ByteString: Collection {

  var startIndex: Int {
    return bytes.startIndex
  }

  var endIndex: Int {
    return bytes.endIndex
  }

  func index(after index: Int) -> Int {

    return bytes.index(after: index)
  }

  subscript(position: Int) -> Byte {
    return bytes[position]
  }
}

extension ByteString: ExpressibleByStringLiteral {

  init(stringLiteral: StaticString) {

    self.bytes = stringLiteral.withUTF8Buffer { return $0.map({ $0 }) }
  }
}

extension ByteString: CustomStringConvertible {

  var description: String {

    return String(utf8: bytes)!
  }
}
