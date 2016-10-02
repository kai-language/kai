
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

        switch try parser.lexer.peek() {
        case .identifier("precedence")?:
          try parser.consume()
          guard case .integer(let value)? = try parser.lexer.peek() else { throw parser.error(.expectedPrecedence) }
          try parser.consume()

          guard let precedence = UInt8(value.description) else { throw parser.error(.expectedPrecedence) }
          try parser.consume(.rbrace)

          try Operator.infix(identifier, bindingPower: precedence)
          return AST.Node(.compilerDeclaration)

        case .identifier("associativity")?:
          unimplemented("associativity is yet to be implemented")

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

          let symbol: Symbol
          if let existingSymbol = SymbolTable.global.lookup(identifier) {
            symbol = existingSymbol
            symbol.types.append(type)
            // TODO(vdka): #10 This 'source' needs to be a per overload thing.
            symbol.source = .llvm
          } else {
            symbol = Symbol(identifier, kind: .procedure, filePosition: position, flags: .compileTime)
            symbol.source = .llvm
            symbol.types.append(type)
            // TODO(vdka): I should think about this. For regular procedure's the current table makes complete sense, however for operator's does it? 
            try SymbolTable.global.insert(symbol)
          }

          return AST.Node(.declaration(symbol), children: [AST.Node(.string(foreignName))])
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

          // TODO(vdka): Not sure what to do for defining this as a symbol yet. Gotta talk with Brett
          let symbol = Symbol(identifier, kind: .type, filePosition: position, flags: .compileTime)
          symbol.source = .llvm
          try SymbolTable.current.insert(symbol)

          return AST.Node(.declaration(symbol), children: [AST.Node(.string(foreignName))])
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
