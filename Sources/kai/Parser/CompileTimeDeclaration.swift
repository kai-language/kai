
extension Parser {

  mutating func parseCompileTimeDeclaration(bindingTo token: Lexer.Token) throws -> (inout Parser) throws -> AST.Node {
    try consume(.keyword(.compilerDeclaration))
    // NOTE(vdka): this still isn't the perfect file position. Ultimately I would like to use the position of the first char of the identifier
    //  currently this will use the first char of the '::' following it. Close enough. For now.
    let position = lexer.filePosition

    let identifier: ByteString
    switch token {
    case .identifier(let id), .operator(let id):
      identifier = id

    default:
      throw error(.badlvalue, message: "The lvalue for a compile time operation must be either an identifier or a defined operator.")
    }

    guard let token = try lexer.peek() else { throw error(.invalidDeclaration, message: "Expected a type for this declaration") }
    switch token {
    case .infixOperator:

      return { parser in
        try parser.consume(.infixOperator)

        try parser.consume(.lbrace)

        var associativity = Operator.Associativity.none
        switch try parser.lexer.peek() {
        case .identifier("associativity")?:
          try parser.consume(.identifier("associativity"))
          switch try parser.lexer.peek() {
          case .identifier("left")?:
            associativity = .left

          case .identifier("right")?:
            associativity = .left

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
      }
    
    case .prefixOperator:
      return { parser in
        try parser.consume()
        guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
        try Operator.prefix(identifier)
        return AST.Node(.compilerDeclaration)
      }

    case .postfixOperator:
      return { parser in
        try parser.consume()
        guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
        try Operator.prefix(identifier)
        unimplemented()
      }

    case .lparen:
      // TODO(vdka): I forgot to add support _here_ for tuples
      return { parser in
        let type = try parser.parseType()

        if case .tuple(_) = type { throw parser.error(.syntaxError) }
        // next should be a new scope '{' or a foreign body
        guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
        if case .lbrace = token { unimplemented("procedure bodies not yet ready") }
        else if case .directive(.foreignLLVM) = token {
          try parser.consume()
          guard case .string(let foreignName)? = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration, message: "Expected foreign symbol name") }
          try parser.consume()

          let symbol = Symbol(identifier, filePosition: position, flags: .compileTime)
          symbol.type = type
          symbol.source = .llvm(foreignName)
          try SymbolTable.current.insert(symbol)

          return AST.Node(.declaration(symbol))
        }

        throw parser.error(.invalidDeclaration, message: "Expected a procedure body")
      }

    case .keyword(.struct):
      return { parser in
        try parser.consume(.keyword(.struct))
        guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
        if case .lbrace = token { unimplemented("Custom struct's are not ready") }
        else if case .directive(.foreignLLVM) = token {
          try parser.consume()
          guard case .string(let foreignName)? = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration, message: "Expected foreign symbol name") }
          try parser.consume()

          let symbol = Symbol(identifier, filePosition: position, flags: .compileTime)
          symbol.type = .type
          symbol.source = .llvm(foreignName)
          try SymbolTable.current.insert(symbol)

          return AST.Node(.declaration(symbol))
        } 
        else { throw parser.error(.syntaxError, message: "Expected struct Body") }
      }

    case .keyword(.enum):
      unimplemented("enum's not yet supported'")

    default:
      throw error(.invalidDeclaration, message: "Unknown compile time declaration type \(token)")
    }
  }
}
