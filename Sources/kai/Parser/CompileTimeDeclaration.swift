
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
    case .infixOperator, .prefixOperator, .postfixOperator:
      unimplemented("TODO: This is tomorrow's job!")

    case .keyword(.struct), .keyword(.enum):
      unimplemented("Defining data structures is not yet implemented")

    default:
      throw error(.invalidDeclaration, message: "Unknown compile time declaration type")
    }
  }
}
