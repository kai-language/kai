

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

    guard let nud = try nud(for: token) else { throw error(.expectedExpression, message: "Expected Expression but got \(token)") }

    var left = try nud(&self)

    // operatorImplementation's need to be skipped too.
    if case .operatorDeclaration = left.kind { return left }
    else if case .declaration(_) = left.kind { return left }

    while let nextToken = try lexer.peek(), let lbp = lbp(for: nextToken),
      rbp < lbp
    {
      guard let led = try led(for: nextToken) else { throw error(.nonInfixOperator) }

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

    case .equals:
      return 10

    default:
      return 0
    }
  }

  mutating func nud(for token: Lexer.Token) throws -> ((inout Parser) throws -> AST.Node)? {

    switch token {
    case .operator(let symbol):
      // If the next token is a colon then this should be a declaration
      switch try (lexer.peek(aheadBy: 1), lexer.peek(aheadBy: 2)) {
      case (.colon?, .colon?):
        return Parser.parseOperatorDeclaration

      default:
        try consume()
        return Operator.table.first(where: { $0.symbol == symbol })?.nud
      }

    case .identifier(let symbol):
      try consume()
      return { parser in AST.Node(.identifier(symbol), filePosition: parser.lexer.filePosition) }

    case .integer(let literal):
      try consume()
      return { _ in AST.Node(.integer(literal)) }

    case .real(let literal):
      try consume()
      return { _ in AST.Node(.real(literal)) }

    case .string(let literal):
      try consume()
      return { _ in AST.Node(.string(literal)) }

    case .keyword(.true):
      try consume()
      return { _ in AST.Node(.boolean(true)) }

    case .keyword(.false):
      try consume()
      return { _ in AST.Node(.boolean(false)) }

    case .lparen:
      try consume()
      return { parser in
        let expr = try parser.expression()
        try parser.consume(.rparen)
        return expr
      }

    case .keyword(.if):
      try consume()
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
      try consume()
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

    default:
      return nil
    }
  }

  mutating func led(for token: Lexer.Token) throws -> ((inout Parser, AST.Node) throws -> AST.Node)? {

    switch token {
    case .operator(let symbol):
      try consume()

      return Operator.table.first(where: { $0.symbol == symbol })?.led

      // NOTE(vdka): Everything below here can be considered a language construct

    case .comma:
      try consume()
      return { parser, lvalue in

        let rhs = try parser.expression(UInt8.max)

        if case .multiple = lvalue.kind { lvalue.children.append(rhs) }
        else { return AST.Node(.multiple, children: [lvalue, rhs]) }

        return lvalue
      }

    case .equals:
      try consume()

      return { parser, lvalue in

        // TODO(vdka): I would like to actually allow x = y = z to be valid.
        let rhs = try parser.expression(9)

        switch lvalue.kind {
        case .identifier(_), .declaration(_), .multiple: // TODO(vdka): Ensure the multiple's children are declarations
          return AST.Node(.assignment("="), children: [lvalue, rhs])

        default:

          throw parser.error(.badlvalue, message: "The expression '\(lvalue.mathy())' cannot be assigned to")
        }
      }

    case .colon:

      if case .colon? = try lexer.peek(aheadBy: 1) { return Parser.parseCompileTimeDeclaration } // '::'
      return { parser, lvalue in
        // ':' 'id' | ':' '=' 'expr'

        try parser.consume(.colon)

        switch lvalue.kind {
        case .identifier(let id):
          // single
          let symbol = Symbol(id, filePosition: parser.lexer.filePosition)
          try SymbolTable.current.insert(symbol)

          switch try parser.lexer.peek() {
          case .equals?: // type infered
            try parser.consume()
            let rhs = try parser.expression()
            return AST.Node(.declaration(symbol), children: [rhs], filePosition: lvalue.filePosition)

          default: // type provided
            let type = try parser.parseType()
            symbol.type = type

            try parser.consume(.equals)
            let rhs = try parser.expression()
            return AST.Node(.declaration(symbol), children: [rhs])
          }

        case .multiple:
          let symbols: [Symbol] = try lvalue.children.map { node in
            guard case .identifier(let id) = node.kind else { throw parser.error(.badlvalue) }
            let symbol = Symbol(id, filePosition: node.filePosition!)
            try SymbolTable.current.insert(symbol)

            return symbol
          }

          switch try parser.lexer.peek() {
          case .equals?:
            // We will need to infer the type. The AST returned will have 2 child nodes.
            try parser.consume()
            let rvalue = try parser.expression()
            // TODO(vdka): Pull the rvalue's children onto the generated node assuming it is a multiple node.

            let lvalue = AST.Node(.multiple, children: symbols.map({ AST.Node(.declaration($0), filePosition: $0.position) }))

            return AST.Node(.multipleDeclaration, children: [lvalue, rvalue], filePosition: symbols.first?.position)

          case .identifier?:
            unimplemented("Explicit types in multiple declaration's is not yet implemented")

          default:
            throw parser.error(.syntaxError)
          }

        case .operator(_):
          unimplemented()

        default:
          fatalError("bad lvalue?")
        }

        unimplemented()

        /*
        let position = parser.lexer.filePosition
        let rhs = try parser.expression(parser.lbp(for: token)!)

        let symbol = Symbol(id, filePosition: position)

        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol), children: [lvalue, rhs])
        */
      }

    default:
      return nil
    }
  }
}


// - MARK: Helpers

extension Parser {

  @discardableResult
  mutating func consume(_ expected: Lexer.Token? = nil) throws -> Lexer.Token {
    guard let expected = expected else {
      // Seems we exhausted the token stream
      // TODO(vdka): Fix this up with a nice error message
      guard try lexer.peek() != nil else { fatalError() }
      return try lexer.pop()
    }

    guard let token = try lexer.peek(), token == expected else {
      throw error(.expected(expected), message: "expected \(expected)") // TODO(vdka): expected \(thing) @ location
    }

    return try lexer.pop()
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
      case ambigiousOperatorUse
      case expectedBody
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
