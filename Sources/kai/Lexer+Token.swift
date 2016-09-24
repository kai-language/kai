
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

    enum Keyword: ByteString {
      case `struct`
      case `enum`

      case `return`
      case returnType = "->"

      case `if`
      case `else`
    }
  }
}
