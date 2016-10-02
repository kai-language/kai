
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

    guard var left = try nud(for: token)?(&self) else { throw error(.expectedExpression, message: "Expected Expression but got \(token)") }
    if case .declaration(_) = left.kind { return left }
    else if case .compilerDeclaration = left.kind { return left }

    while let token = try lexer.peek(), let lbp = lbp(for: token),
      rbp < lbp
    {

      try lexer.pop()
      guard let led = try led(for: token) else {
        throw error(.nonInfixOperator)
      }
      left = try led(&self, left)
    }

    return left
  }
}

extension Parser {

  func lbp(for token: Lexer.Token) -> UInt8? {

    switch token {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.lbp

    case .keyword(.declaration), .keyword(.compilerDeclaration):
      return 10

    default:
      return 0
    }
  }

  mutating func nud(for token: Lexer.Token) throws -> ((inout Parser) throws -> AST.Node)? {

    if case .keyword(.compilerDeclaration)? = try lexer.peek(aheadBy: 1) {
      return try parseCompileTimeDeclaration(bindingTo: token)
    }

    switch token {
    case .operator(let symbol):
      // If we have `+ ::` then parse that as a Definition | Declaration of an operator
      if case .keyword(.compilerDeclaration)? = try lexer.peek(aheadBy: 1) {
        return { (parser: inout Parser) in
          // parse + :: infix operator { associatvity left precedence 50 }
          try parser.consume(.keyword(.compilerDeclaration))

          switch try parser.lexer.peek() {
          case .infixOperator?:
            try parser.consume()
            guard case .lbrace? = try parser.lexer.peek() else {
              try Operator.infix(symbol, bindingPower: 50)
              // TODO(vdka): We can reasonably default an operator to non-associative. But what about precedence?
              return AST.Node(.compilerDeclaration)
            }
            try parser.consume()
            switch try parser.lexer.peek() {
            case .identifier(let id)? where id == "precedence":
              try parser.consume()
              
              guard case .integer(let value)? = try parser.lexer.peek() else { throw parser.error(.expectedPrecedence) }

              try parser.consume()

              guard let precedence = UInt8(value.description) else { throw parser.error(.expectedPrecedence) }

              try parser.consume(.rbrace)

              try Operator.infix(symbol, bindingPower: precedence)
              return AST.Node(.compilerDeclaration)

              // TODO(vdka): we should support { associativty left precedence 50 } & { precedence 50 }

            default:
              fatalError()
            }

          case .prefixOperator?:
            try parser.consume()
            guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
            try Operator.prefix(symbol)
            return AST.Node(.compilerDeclaration)

          case .postfixOperator?:
            try parser.consume()
            guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
            unimplemented()
//            return AST.Node(.operatorDeclaration)

          default:
            throw parser.error(.expectedOperator)
          }
        }
      } else {

        return Operator.table.first(where: { $0.symbol == symbol })?.nud
      }

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

    case .lbrace:
      return { parser in

        let scopeSymbols = SymbolTable.push()
        defer { SymbolTable.pop() }

        let node = AST.Node(.scope(scopeSymbols))
        while let next = try parser.lexer.peek(), next != .rbrace {
          let expr = try parser.expression()
          node.add(expr)
        }
        try parser.consume(.rbrace)
        
        return node
      }

    default: return nil
    }
  }

  mutating func led(for token: Lexer.Token) throws -> ((inout Parser, AST.Node) throws -> AST.Node)? {

    switch token {
    case .operator(let symbol):

      return Operator.table.first(where: { $0.symbol == symbol })?.led

      // NOTE(vdka): Everything below here can be considered a language construct

    case .keyword(.declaration):
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`
      return { parser, lvalue in
        guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }

        let position = parser.lexer.filePosition
        let rhs = try parser.expression(parser.lbp(for: token)!)
        

        let symbol = Symbol(id, filePosition: position)

        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol), children: [lvalue, rhs])
      }

    case .keyword(.compilerDeclaration):
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`

      return { parser, lvalue in

        guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }

        let position = parser.lexer.filePosition

        let rhs = try parser.expression(parser.lbp(for: token)!)

        let symbol = Symbol(id, filePosition: position, flags: .compileTime)

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
      case unaryOperatorBodyForbidden
      case expectedPrecedence
      case expectedOperator
      case expectedExpression
      case nonInfixOperator
      case invalidDeclaration
      case syntaxError
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
