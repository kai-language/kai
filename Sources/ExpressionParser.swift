
/// TODO(vdka): This parser is basic recursive descent and doesn't
///   handle the user defining new operators in their code. Fine for now.
struct ExpressionParser {

  var scanner: BufferedScanner<Lexer.Token>

  init(_ lexer: Lexer) {
    self.scanner = BufferedScanner(lexer)
  }

  init(_ scanner: inout BufferedScanner<Lexer.Token>) {
    self.scanner = scanner
  }

  mutating func parseNumber() throws -> AST.Node {
    guard let token = scanner.peek() else { throw Error.invalidExpression }
    scanner.pop()
    return AST.Node(.integerLiteral(token.value))
  }

  mutating func parseFactor() throws -> AST.Node {
    guard let token = scanner.peek() else { throw Error.invalidExpression }

    switch token.type {
    case .identifier:
      scanner.pop()
      return AST.Node(.identifier(token.value))

    case .integer, .real:
      return try parseNumber()

    // TODO(vdka): Add in parsing of calls, strings, subscripts etc.

    case .openParentheses:
      scanner.pop()
      let expr = try parseExpression()
      guard case .closeParentheses? = scanner.peek()?.type else { throw Error.unmatchedParentheses }
      scanner.pop()
      return expr

    default:
      throw Error.invalidExpression
    }
  }

  mutating func parseTerm() throws -> AST.Node {

    let lhs = try parseFactor()

    guard let token = scanner.peek(),
      token.type == .asterisk || token.type == .solidus else { return lhs }
    scanner.pop()

    let opNode = AST.Node(.op(token.value))

    let rhs = try parseTerm()

    opNode.add(children: [lhs, rhs])

    return opNode
  }

  mutating func parseExpression() throws -> AST.Node {
    let isNegated = scanner.peek()?.type == .minus
    if isNegated { scanner.pop() }

    let lhs = try parseTerm()

    guard let token = scanner.peek(),
      token.type == .plus || token.type == .minus else { return lhs }
    scanner.pop()

    let opNode = AST.Node(.op(token.value))

    let rhs = try parseTerm()

    opNode.add(children: [lhs, rhs])

    return opNode
  }

  enum Error: Swift.Error {
    case invalidExpression
    case unmatchedParentheses
    case invalidNumber
  }
}
