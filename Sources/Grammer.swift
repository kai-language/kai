
let keywords: Set<ByteString> = ["let", "var", "struct"]
let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]"
  ]
let whitespace: Set<UTF8.CodeUnit> = [" ", "\t", "\n"]

extension Lexer {

  struct Token {

    var filePosition: FileScanner.Position

    var type: Lexer.TokenType
    var value: ByteString?

    init(type: Lexer.TokenType, value: ByteString?, filePosition: FileScanner.Position) {

      self.filePosition = filePosition

      self.type = type
      self.value = type.defaultValue ?? value

      // set the column position to the start of the token
//      self.filePosition.column -= numericCast(value?.count ?? 0)
    }
  }
}

extension Lexer {

  enum TokenType {

    case unknown

    case comment

    case identifier

    case openBrace
    case closeBrace
    case openBracket
    case closeBracket
    case openParentheses
    case closeParentheses

    case doubleQuote
    case singleQuote

    case solidus
    case asterisk
    case plus
    case minus

    case equals
    case colon
    case hash

    case string
    case integer
    case float

    case endOfStream

    var defaultValue: ByteString? {

      switch self {
      case .openBrace:        return "{"
      case .closeBrace:       return "}"
      case .openBracket:      return "["
      case .closeBracket:     return "]"
      case .openParentheses:  return "("
      case .closeParentheses: return ")"
      case .doubleQuote:      return "\""
      case .singleQuote:      return "'"
      case .equals:           return "="
      case .colon:            return ":"
      case .hash:             return "#"

      case .solidus:          return "/"
      case .asterisk:         return "*"
      case .plus:             return "+"
      case .minus:            return "-"

      default:                return nil
      }
    }
  }
}
