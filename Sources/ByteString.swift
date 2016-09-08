
import ByteHashable

struct ByteString {

  var bytes: [Byte]

  init<S: Sequence>(_ bytes: S) where S.Iterator.Element == Byte {

    self.bytes = Array(bytes)
  }

  /// append
  static func + (lhs: ByteString, rhs: ByteString) -> ByteString {

    return ByteString(lhs.bytes + rhs.bytes)
  }

  static func + (lhs: String, rhs: ByteString) -> ByteString {

    return ByteString(Array(lhs.utf8) + rhs.bytes)
  }

  static func + (lhs: ByteString, rhs: String) -> ByteString {

    return ByteString(lhs + Array(rhs.utf8))
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

  var lastIndex: Int {
    return bytes.endIndex - 1
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

  func hasPrefix(_ prefix: ByteString) -> Bool {
    guard prefix.count <= self.count else { return false }
    for (index, char) in prefix.enumerated() {

      guard self[index] == char else { return false }
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

extension ByteString {

  init(_ string: Swift.String) {

    self.bytes = Array(string.utf8)
  }
}

extension ByteString {

  mutating func append(_ char: Byte) {
    bytes.append(char)
  }

  mutating func append(contentsOf suffix: ByteString) {
    bytes.append(contentsOf: suffix.bytes)
  }

  mutating func removeAll(keepingCapacity: Bool = false) {
    bytes.removeAll(keepingCapacity: keepingCapacity)
  }

  mutating func removeLast() -> Byte {
    return bytes.removeLast()
  }

  mutating func removeLast(_ n: Int) {
    bytes.removeLast(n)
  }
}
