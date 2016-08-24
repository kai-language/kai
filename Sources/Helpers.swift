

/*
  Miscelaneous methods extensions and other tidbits of useful functionality
  that is general enough to not belong in other files.
*/

extension Sequence {

  /// Used to check if a sequence follows some rule you pass it.
  func follows(rule: (Iterator.Element) -> Bool) -> Bool {

    for item in self {
      guard rule(item) else { return false }
    }

    return true
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

