
extension Parser {

  static func parseOperatorDeclaration(for op: ByteString) -> (inout Parser) throws -> AST.Node {

    return { parser in

      try parser.consume(.colon)
      try parser.consume(.colon)

      guard let token = try parser.lexer.peek() else { throw parser.error(.expectedOperator) }
      try parser.consume()
      try parser.consume(.identifier("operator"))
      switch token {
      case .identifier("infix"):
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

          // precedence is required.
          fallthrough

        case .identifier("precedence")?:
          try parser.consume(.identifier("precedence"))
          guard case .integer(let value)? = try parser.lexer.peek() else { throw parser.error(.expectedPrecedence) }
          try parser.consume()

          guard let precedence = UInt8(value.description) else { throw parser.error(.expectedPrecedence) }
          try parser.consume(.rbrace)

          try Operator.infix(op, bindingPower: precedence, associativity: associativity)
          return AST.Node(.operatorDeclaration)

        default:
          throw parser.error(.expectedPrecedence)
        }

      case .identifier("prefix"):
        guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
        try Operator.prefix(op)
        return AST.Node(.operatorDeclaration)

      case .identifier("postfix"):
        guard try parser.lexer.peek() != .lbrace else { throw parser.error(.unaryOperatorBodyForbidden) }
        try Operator.prefix(op)
        unimplemented()

      default:
        throw parser.error(.syntaxError, message: "There was an issue with the declaration of an operator")
      }
    }
  }
}
