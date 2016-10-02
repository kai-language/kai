
extension Lexer {

  enum Token {
    case unknown

    case directive(Directive)
    case keyword(Keyword)
    case identifier(ByteString)
    case `operator`(ByteString)

    case string(ByteString)
    case integer(ByteString)
    case real(ByteString)

    case lparen
    case rparen
    case lbrace
    case rbrace

    case infixOperator
    case prefixOperator
    case postfixOperator

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

      case returnType = "->"
      case declaration = ":="
      case compilerDeclaration = "::"
    }

    enum Directive: ByteString {
      case foreignLLVM = "foreign(LLVM)"
    }
  }
}

extension Lexer.Token: Equatable {

  static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {
    switch (lhs, rhs) {
    case (.keyword(let l), .keyword(let r)): return l == r
    case (.identifier(let l), .identifier(let r)): return l == r
    case (.operator(let l), .operator(let r)): return l == r
    case (.string(let l), .string(let r)): return l == r
    case (.integer(let l), .identifier(let r)): return l == r
    case (.real(let l), .real(let r)): return l == r

    default: return isMemoryEquivalent(lhs, rhs)
    }
  }
}
