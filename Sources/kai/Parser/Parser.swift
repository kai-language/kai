

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

    while let token = try lexer.peek(), let lbp = lbp(for: token),
      rbp < lbp
    {

      try lexer.pop()
      guard let led = try led(for: token) else { throw error(.nonInfixOperator) }
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

      // TODO(vdka): what lbp do I want here?
    case .colon, .comma:
      return UInt8.max

    default:
      return 0
    }
  }

  mutating func nud(for token: Lexer.Token) throws -> ((inout Parser) throws -> AST.Node)? {

    switch token {
    case .operator(let symbol):
      // If the next token is a colon then this should be a declaration
      if case .colon? = try lexer.peek() { return { _ in AST.Node(.operator(symbol)) } }
      else { return Operator.table.first(where: { $0.symbol == symbol })?.nud }

    case .identifier(let symbol):
      return { parser in
        let node = AST.Node(.identifier(symbol))

        return node
      }

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

    case .comma:
      return { parser, lvalue in

        let rhs = try parser.expression(UInt8.max)

        if case .multiple = lvalue.kind { lvalue.children.append(rhs) }
        else { return AST.Node(.multiple, children: [lvalue, rhs], filePosition: lvalue.filePosition) }

        return lvalue
      }

    case .colon:
      if case .colon? = try lexer.peek(aheadBy: 1) { return Parser.parseCompileTimeDeclaration }
      return { parser, lvalue in

        try parser.consume(.colon)

        switch lvalue.kind {
        case .identifier(let id):
          let symbol = Symbol(id, filePosition: parser.lexer.filePosition)
          try SymbolTable.current.insert(symbol)

        case .multiple:
          let symbols = try lvalue.children.map { node in
            guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }
            let symbol = Symbol(id, filePosition: lvalue.filePosition!)
            try SymbolTable.current.insert(symbol)

            return symbol
          }

          let no = AST.init(.declaration, parent: <#T##AST.Node?#>, children: <#T##[AST.Node]#>, filePosition: <#T##FileScanner.Position?#>)

        case .operator(let op):
          unimplemented()

        default:
          fatalError("bad lvalue?")
        }

        let position = parser.lexer.filePosition
        let rhs = try parser.expression(parser.lbp(for: token)!)

        let symbol = Symbol(id, filePosition: position)

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
