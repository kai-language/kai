
import ByteHashable

struct ByteString {

  typealias Byte = UInt8

  var bytes: [Byte]

  init<S: Sequence>(_ bytes: S) where S.Iterator.Element == Byte {

    self.bytes = Array(bytes)
  }

  /// append
  static func + (lhs: ByteString, rhs: ByteString) -> ByteString {

    return ByteString(lhs.bytes + rhs.bytes)
  }
}

extension ByteString: Hashable {

  var hashValue: Int {

    var h = 0
    for byte in bytes {
      h = h &+ numericCast(byte)
      h = h &+ (h << 10)
      h ^= (h >> 6)
    }

    h = h &+ (h << 3)
    h ^= (h >> 11)
    h = h &+ (h << 15)

    return h
  }
}

extension ByteString: Equatable {

  static func == (lhs: ByteString, rhs: ByteString) -> Bool {
    return lhs.bytes == rhs.bytes
  }
}

extension ByteString: BidirectionalCollection {

  var startIndex: Int {
    return bytes.startIndex
  }

  var endIndex: Int {
    return bytes.endIndex
  }

  func index(after index: Int) -> Int {

    return bytes.index(after: index)
  }

  func index(before index: Int) -> Int {

    return bytes.index(before: index)
  }

  subscript(position: Int) -> Byte {
    return bytes[position]
  }
}

extension ByteString {

  func hasSuffix(_ suffix: ByteString) -> Bool {
    guard suffix.count <= self.count else { return false }
    for (index, char) in suffix.enumerated() {
      let selfIndex = (self.count - suffix.count) + index

      guard self[selfIndex] == char else { return false }
    }

    return true
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

