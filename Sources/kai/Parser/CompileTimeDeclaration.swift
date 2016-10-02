
extension Parser {

  mutating func parseCompileTimeDeclaration(bindingTo token: Lexer.Token) throws -> (inout Parser) throws -> AST.Node {
    try consume(.keyword(.compilerDeclaration))

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
          guard case .string(let foreignName)? = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration) }
          try parser.consume()

          // TODO(vdka): FilePosition should be the start of the decl
          // TODO(vdka): What are the semantic diferences between a procedure and a variable. Should they even exist?  

          let symbol: Symbol
          if let existingSymbol = SymbolTable.global.lookup(identifier) {
            symbol = existingSymbol
            symbol.types.append(type)
            // TODO(vdka): This 'source' needs to be a per overload thing.
            symbol.source = .llvm
          } else {
            symbol = Symbol(identifier, kind: .procedure, filePosition: parser.lexer.filePosition, flags: .compileTime)
            symbol.source = .llvm
            symbol.types.append(type)
            try SymbolTable.global.insert(symbol)
          }

          return AST.Node(.declaration(symbol), children: [AST.Node(.string(foreignName))])
        }

        throw parser.error(.invalidDeclaration, message: "Expected a procedure body")
      }

    case .keyword(.struct), .keyword(.enum):
      unimplemented("Defining data structures is not yet implemented")

    default:
      throw error(.invalidDeclaration, message: "Unknown compile time declaration type \(token)")
    }
  }
}
