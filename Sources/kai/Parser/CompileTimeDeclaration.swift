
extension Parser {

  static func parseCompileTimeDeclaration(parser: inout Parser, lvalue: AST.Node) throws -> AST.Node {
    try parser.consume(.colon)
    try parser.consume(.colon)

    let position = parser.lexer.filePosition
    let identifier: ByteString
    switch lvalue.kind {
    case .identifier(let id), .operator(let id):
      identifier = id

    default:
      throw parser.error(.badlvalue, message: "The lvalue for a compile time operation must be either an identifier or operator")
    }


    guard let token = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration, message: "Expected a type for this declaration") }
    switch token {
    case .infixOperator:
      try parser.consume(.infixOperator)
      try parser.consume(.lbrace)

      var associativity = Operator.Associativity.none
      switch try parser.lexer.peek() {
      case .identifier("associativity")?:
        try parser.consume()

        switch try parser.lexer.peek() {
        case .identifier("left")?:
          associativity = .left

        case .identifier("right")?:
          associativity = .right

        default:
          throw parser.error(.syntaxError)
        }

        try parser.consume()

        fallthrough

      case .identifier("precedence")?:
        try parser.consume(.identifier("precedence"))
        guard case .integer(let value)? = try parser.lexer.peek() else { throw parser.error(.expectedPrecedence) }
        try parser.consume()

        guard let precedence = UInt8(value.description) else { throw parser.error(.expectedPrecedence) }
        try parser.consume(.rbrace)

        try Operator.infix(identifier, bindingPower: precedence, associativity: associativity)
        return AST.Node(.compilerDeclaration)

      default:
        throw parser.error(.expectedPrecedence)
      }


    case .prefixOperator:
      try parser.consume()
      guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
      try Operator.prefix(identifier)
      return AST.Node(.compilerDeclaration)


    case .postfixOperator:
        try parser.consume()
        guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
        try Operator.prefix(identifier)
        unimplemented()


    case .lparen:
      let type = try parser.parseType()

      if case .tuple(_) = type { throw parser.error(.syntaxError) }
      // next should be a new scope '{' or a foreign body
      guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
      if case .lbrace = token { unimplemented("procedure bodies not yet ready") }
      else if case .directive(.foreignLLVM) = token {
        try parser.consume()
        guard case .string(let foreignName)? = try parser.lexer.peek() else {
          throw parser.error(.invalidDeclaration, message: "Expected foreign symbol name")
        }
        try parser.consume()

        let symbol = Symbol(identifier, filePosition: position, flags: .compileTime)
        symbol.type = type
        symbol.source = .llvm(foreignName)
        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol))
      }


    case .keyword(.struct):
      try parser.consume(.keyword(.struct))
      guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
      if case .lbrace = token { unimplemented("Custom struct's are not ready") }
      else if case .directive(.foreignLLVM) = token {
        try parser.consume()
        guard case .string(let foreignName)? = try parser.lexer.peek() else {
          throw parser.error(.invalidDeclaration, message: "Expected foreign symbol name")
        }
        try parser.consume()

        let symbol = Symbol(identifier, filePosition: position, flags: .compileTime)
        symbol.type = .type
        symbol.source = .llvm(foreignName)
        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol))
      }
      else { throw parser.error(.syntaxError, message: "Expected struct Body") }


    case .keyword(.enum):
      unimplemented("enum's not yet supported'")


    default:
      throw parser.error(.syntaxError)
    }

    fatalError("TODO: What happened here")
  }
}

