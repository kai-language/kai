
// MARK: - Stdlib extensions

extension UTF8.CodeUnit: ExpressibleByUnicodeScalarLiteral {

  public init(unicodeScalarLiteral: UnicodeScalar) {
    self = numericCast(unicodeScalarLiteral.value)
  }
}

extension String {

  init?<S: Sequence>(utf8: S) where S.Iterator.Element == UTF8.CodeUnit {

    var codec = UTF8()
    var str = ""
    var codeUnits = utf8.makeIterator()
    var done = false
    while !done {
      let r = codec.decode(&codeUnits)
      switch (r) {
      case .emptyInput:
        done = true
      case .scalarValue(let scalar):
        str.append(Character(scalar))
      case .error:
        return nil
      }
    }
    self = str
  }
}
