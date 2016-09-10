
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
