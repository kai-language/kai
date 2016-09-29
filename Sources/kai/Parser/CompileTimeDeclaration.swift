
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
          return AST.Node(.operatorDeclaration)

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
        return AST.Node(.operatorDeclaration)
      }

    case .postfixOperator:
      return { parser in
        try parser.consume()
        guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
        try Operator.prefix(identifier)
        unimplemented()
      }

    case .lparen:
      unimplemented("Parsing either tuples or procedure types is a tomorrow goal")

    case .keyword(.struct), .keyword(.enum):
      unimplemented("Defining data structures is not yet implemented")

    default:
      throw error(.invalidDeclaration, message: "Unknown compile time declaration type \(token)")
    }
  }
}
