
protocol CompilerError: Swift.Error, CustomStringConvertible {
  var message: String? { get }
  var filePosition: FileScanner.Position { get }
}

extension CompilerError {

  var description: String {

    return "error[\(filePosition)]: \(message ?? "Something went wrong")"
  }
}

extension FileScanner.Position: CustomStringConvertible {

  var description: String {
    let baseName = fileName.characters.split(separator: "/").map(String.init).last!
    return "\(baseName):\(line):\(column)"
  }
}

typealias Byte = UInt8

/*
  Miscelaneous methods extensions and other tidbits of useful functionality
  that is general enough to not belong in other files.
*/

extension BidirectionalCollection where Index == Int {

  /// The Actual last indexable position of the array
  var lastIndex: Index {
    return endIndex - 1
  }
}

extension Set {

  init<S: Sequence>(_ sequences: S...)
    where S.Iterator.Element: Hashable, S.Iterator.Element == Element
  {

    self.init()

    for element in sequences.joined() {
      insert(element)
    }
  }
}

// Combats Boilerplate
extension ExpressibleByStringLiteral where StringLiteralType == StaticString {

  public init(unicodeScalarLiteral value: StaticString) {
    self.init(stringLiteral: value)
  }

  public init(extendedGraphemeClusterLiteral value: StaticString) {
    self.init(stringLiteral: value)
  }
}

// NOTE(vdka): This should only be used in development, there are better ways to do things.
func isMemoryEquivalent<A, B>(_ lhs: A, _ rhs: B) -> Bool {
  var (lhs, rhs) = (lhs, rhs)

  guard MemoryLayout<A>.size == MemoryLayout<B>.size else { return false }

  let lhsPointer = withUnsafePointer(to: &lhs) { $0 }
  let rhsPointer = withUnsafePointer(to: &rhs) { $0 }

  let lhsFirstByte = unsafeBitCast(lhsPointer, to: UnsafePointer<Byte>.self)
  let rhsFirstByte = unsafeBitCast(rhsPointer, to: UnsafePointer<Byte>.self)

  let lhsBytes = UnsafeBufferPointer(start: lhsFirstByte, count: MemoryLayout<A>.size)
  let rhsBytes = UnsafeBufferPointer(start: rhsFirstByte, count: MemoryLayout<B>.size)

  for (leftByte, rightByte) in zip(lhsBytes, rhsBytes) {
    guard leftByte == rightByte else { return false }
  }

  return true

}

import Darwin

func unimplemented(_ featureName: String, file: StaticString = #file, line: UInt = #line) -> Never {
  print("\(file):\(line): Unimplemented feature \(featureName).")
  exit(1)
}

func debug<T>(_ value: T, file: StaticString = #file, line: UInt = #line) {
  print("\(line): \(value)")
  fflush(stdout)
}

func debug(file: StaticString = #file, line: UInt = #line) {
  print("\(line): HERE")
  fflush(stdout)
}

func unimplemented(file: StaticString = #file, line: UInt = #line) -> Never {
  print("\(file):\(line): Unimplemented feature.")
  exit(1)
}
