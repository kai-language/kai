
struct Parser {

  var lexer: Lexer

  init(_ lexer: inout Lexer) {
    self.lexer = lexer
  }

  static func parse(_ lexer: inout Lexer) throws -> AST {

    var parser = Parser(&lexer)

    let node = AST.Node(.file(name: "main.kai"))

    while true {
      let expr = try parser.expression()
      guard expr.kind != .empty else { return node }

      node.children.append(expr)
    }
  }

  mutating func expression(_ rbp: UInt8 = 0) throws -> AST.Node {
    guard let token = try lexer.peek() else { return AST.Node(.empty) }
    try lexer.pop()

    guard var left = try token.nud?(&self) else { throw error(.expectedExpression, message: "Expected expression") }

    while let token = try lexer.peek(), let lbp = token.lbp,
      rbp < lbp
    {

      try lexer.pop()
      guard let led = token.led else { throw error(.nonInfixOperator) }
      left = try led(&self, left)
    }

    return left
  }
}


// - MARK: Helpers

extension Parser {

  mutating func consume(_ expected: Lexer.Token) throws {
    guard let token = try lexer.peek(), token == expected else {
      throw error(.expected(expected), message: "expected \(expected)")
    }
    try lexer.pop()
  }

  func error(_ reason: Error.Reason, message: String? = nil) -> Swift.Error {
    return Error(reason: reason, filePosition: lexer.filePosition, message: message)
  }
}

extension Parser {

  struct Error: CompilerError {

    var reason: Reason
    var filePosition: FileScanner.Position
    var message: String?

    enum Reason: Swift.Error {
      case expected(Lexer.Token)
      case undefinedIdentifier(ByteString)
      case expectedExpression
      case nonInfixOperator
      case badlvalue
    }
  }
}

extension Parser.Error.Reason: Equatable {

  static func == (lhs: Parser.Error.Reason, rhs: Parser.Error.Reason) -> Bool {

    switch (lhs, rhs) {
    case (.expected(let l), .expected(let r)): return l == r
    case (.undefinedIdentifier(let l), .undefinedIdentifier(let r)): return l == r
    default: return isMemoryEquivalent(lhs, rhs)
    }
  }
}
