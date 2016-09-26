
extension Lexer {

  enum Token {
    case unknown

    case keyword(Keyword)
    case identifier(ByteString)
    case `operator`(ByteString)

    case string(ByteString)
    case integer(ByteString)
    case real(ByteString)

    case lparen
    case rparen
    case colon
    case comma

    enum Keyword: ByteString {
      case `struct`
      case `enum`

      case `return`
      case returnType = "->"
      case declaration = ":="

      case `if`
      case `else`
    }
  }
}

extension Lexer.Token: Equatable {

  static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {
    switch (lhs, rhs) {
    case (.unknown, .unknown): return true
    case (.keyword(let l), .keyword(let r)): return l == r
    case (.identifier(let l), .identifier(let r)): return l == r
    case (.operator(let l), .operator(let r)): return l == r
    case (.string(let l), .string(let r)): return l == r
    case (.integer(let l), .identifier(let r)): return l == r
    case (.real(let l), .real(let r)): return l == r
    case (.lparen, .lparen): return true
    case (.rparen, .rparen): return true

    default: return false
    }
  }
}
