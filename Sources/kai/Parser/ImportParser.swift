
extension ByteString {

  func consume(with chars: [Byte]) -> ByteString {

    var str: ByteString = ""

    var iterator = self.bytes.makeIterator()

    while let byte = iterator.next(), chars.contains(byte) {
      str.append(byte)
    }

    return str
  }
}

extension Parser {

  /// Parses the the lexer sequence [.directive(.import), .string(_)].
  /// Will then declare all of the Operator's in that scope.
  /// Imported entities have their own _namespace_ by default this is the name of the file.
  /// The namespace file entities are imported as can be _aliased_ to another name using 'as alias'
  static func parseImportDirective(parser: inout Parser) throws -> AST.Node {
    try parser.consume(.directive(.import))
    guard case .string(let fileName)? = try parser.lexer.peek()?.kind else { throw parser.error(.syntaxError, message: "Expected a filename to import") }

    try parser.consume()

    if case .identifier("as")? = try parser.lexer.peek()?.kind {
      try parser.consume()

      switch try parser.lexer.peek()?.kind {
      case .dot?:
        try parser.consume()
        return AST.Node(.import(file: fileName.description, namespace: nil))

      case .identifier(let alias)?:
        try parser.consume()
        return AST.Node(.import(file: fileName.description, namespace: alias.description))

      default:
        throw parser.error(message: "Expected an identifier or '.' following 'as'")
      }
    } else {
      let fileIdentifier = fileName.consume(with: identChars).description
      return AST.Node(.import(file: fileName.description, namespace: fileIdentifier))
    }
  }
}
