
extension Lexer {

  enum Token {
    case unknown

    case keyword(Keyword)
    case identifier(ByteString)
    case `operator`(ByteString)

    case boolean(Bool)
    case string(ByteString)
    case integer(ByteString)
    case real(ByteString)

    case lparen
    case rparen
    case lbracket
    case rbracket

    case colon
    case comma

    enum Keyword: ByteString {
      case `struct`
      case `enum`

      case `true`
      case `false`

      case `if`
      case `else`
      case `return`

      case `operator`
      case infix
      case prefix
      case postfix

      case returnType = "->"
      case declaration = ":="
      case compilerDeclaration = "::"
    }
  }
}

extension Lexer.Token: Equatable {

  static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {
    switch (lhs, rhs) {
    case (.keyword(let l), .keyword(let r)): return l == r
    case (.identifier(let l), .identifier(let r)): return l == r
    case (.operator(let l), .operator(let r)): return l == r
    case (.boolean(let l), .boolean(let r)): return l == r
    case (.string(let l), .string(let r)): return l == r
    case (.integer(let l), .identifier(let r)): return l == r
    case (.real(let l), .real(let r)): return l == r

    default: return isMemoryEquivalent(lhs, rhs)
    }
  }
}
