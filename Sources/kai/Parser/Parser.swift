
struct Parser {

  var lexer: Lexer

  init(_ lexer: inout Lexer) {
    self.lexer = lexer
  }

  static func parse(_ lexer: inout Lexer) throws -> AST {

    var parser = Parser(&lexer)

    let node = AST.Node(.file(name: lexer.filePosition.fileName))

    while true {
      let expr = try parser.expression()
      guard expr.kind != .empty else { return node }

      node.children.append(expr)
    }
  }

  mutating func expression(_ rbp: UInt8 = 0) throws -> AST.Node {
    // TODO(vdka): This should probably throw instead of returning an empty node. What does an empty AST.Node even mean.
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

extension Lexer.Token {

  var lbp: UInt8? {
    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.lbp

    case .keyword(.declaration), .keyword(.compilerDeclaration):
      return 10

    default:
      return 0
    }
  }

  var nud: ((inout Parser) throws -> AST.Node)? {

    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.nud

    case .identifier(let symbol):
      return { _ in AST.Node(.identifier(symbol)) }

    case .integer(let literal):
      return { _ in AST.Node(.integer(literal)) }

    case .real(let literal):
      return { _ in AST.Node(.real(literal)) }

    case .string(let literal):
      return { _ in AST.Node(.string(literal)) }

    case .keyword(.true):
      return { _ in AST.Node(.boolean(true)) }

    case .keyword(.false):
      return { _ in AST.Node(.boolean(false)) }

    case .lparen:
      return { parser in
        let expr = try parser.expression()
        try parser.consume(.rparen)
        return expr
      }

    case .keyword(.if):
      return { parser in

        let conditionExpression = try parser.expression()
        let thenExpression = try parser.expression()

        guard case .keyword(.else)? = try parser.lexer.peek() else {
          return AST.Node(.conditional, children: [conditionExpression, thenExpression])
        }

        try parser.consume(.keyword(.else))
        let elseExpression = try parser.expression()
        return AST.Node(.conditional, children: [conditionExpression, thenExpression, elseExpression])
      }

    case .prefixOperator:
      return { parser in

        guard case .operator(let symbol)? = try parser.lexer.peek() else { throw parser.error(.expectedOperator, message: "Expected an operator") }
        try parser.consume()

        try Operator.prefix(symbol)

        return AST.Node(.prefixOperator(symbol))
      }

    case .postfixOperator:
      return { parser in

        guard case .operator(let symbol)? = try parser.lexer.peek() else { throw parser.error(.expectedOperator, message: "Expected an operator") }
        try parser.consume()

        // TODO(vdka): Add support for postfix operators
        // NOTE(vdka): For now we shall parse them but do nothing with them.
        //        try Operator.postfix(symbol)

        return AST.Node(.postfixOperator(symbol))
      }

    case .infixOperator:
      return { parser in

        guard case .operator(let symbol)? = try parser.lexer.peek() else { throw parser.error(.expectedOperator, message: "Expected an operator") }
        try parser.consume()

        // TODO(vdka): Parse the body '{ associativity left precedence 50 }' instead of defaulting
        try Operator.infix(symbol, bindingPower: 50)

        return AST.Node(.infixOperator(symbol))
      }


    case .lbracket:
      return { parser in

        // TODO(vdka): Traverse the AST upward, looking for parent scopes. if there are none, our parent is the global scope.

        let scopeSymbols = SymbolTable.push()
        defer {
          SymbolTable.pop()
        }

        let node = AST.Node(.scope(scopeSymbols))
        while let next = try parser.lexer.peek(), next != .rbracket {
          let expr = try parser.expression()
          node.add(expr)
        }
        try parser.consume(.rbracket)

        return node
      }

    default:
      return nil
    }
  }

  var led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)? {

    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.led

      // NOTE(vdka): Everything below here can be considered a language construct

    case .keyword(.declaration):
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`
      return { parser, lvalue in
        guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }

        let position = parser.lexer.filePosition
        let rhs = try parser.expression(self.lbp!)

        let symbol = Symbol(id, kind: .variable, filePosition: position)

        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol), children: [lvalue, rhs])
      }

    case .keyword(.compilerDeclaration):
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`
      return { parser, lvalue in
        guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }

        let position = parser.lexer.filePosition

        let rhs = try parser.expression(self.lbp!)
        
        let symbol = Symbol(id, kind: .variable, filePosition: position, flags: .compileTime)
        
        try SymbolTable.current.insert(symbol)
        
        return AST.Node(.declaration(symbol), children: [lvalue, rhs])
      }
      
    default:
      return nil
    }
  }
}


// - MARK: Helpers

extension Parser {

  mutating func consume(_ expected: Lexer.Token? = nil) throws {
    guard let expected = expected else {
      // Seems we exhausted the token stream
      // TODO(vdka): Fix this up with a nice error message
      guard try lexer.peek() != nil else { fatalError() }
      try lexer.pop()

      return
    }

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
      case operatorRedefinition
      case expectedOperator
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
