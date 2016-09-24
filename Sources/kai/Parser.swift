
struct Parser {

  var scanner: BufferedScanner<Lexer.Token>
  var symbols = SymbolTable()

  init(_ lexer: Lexer) {
    self.scanner = BufferedScanner(lexer)
  }

  static func parse(_ lexer: Lexer) throws -> AST {

    var parser = Parser(lexer)

    return try parser.expression()
  }

  mutating func expression(_ rbp: Int16 = 0) throws -> AST.Node {
    guard let token = scanner.peek() else { return AST.Node(.empty) }
    scanner.pop()

    guard var left = try token.nud?(&self) else { throw error(.expectedAtom) }

    while let token = scanner.peek(), let bindingPower = token.bindingPower,
      rbp < bindingPower
    {

      scanner.pop()
      guard let led = token.led else { throw error(.nonInfixOperator) }
      left = try led(&self, left)
    }

    return left
  }
}


// - MARK: Helpers

extension Parser {

  func error(_ reason: Error.Reason, message: String? = nil) -> Swift.Error {
    return Error(reason: reason, message: message)
  }
}

extension Parser {

  struct Error: Swift.Error {

    var reason: Reason
    var message: String?

    enum Reason: Swift.Error {
      case expectedAtom
      case nonInfixOperator
    }
  }
}
