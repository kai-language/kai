
let keywords: Set<ByteString> = ["let", "var", "struct"]
let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]"
  ]
let whitespace: Set<UTF8.CodeUnit> = [" ", "\t", "\n"]

extension Tokenizer {

  struct Token {

    var filePosition: FileScanner.Position

    var type: Tokenizer.TokenType
    var value: ByteString?

    init(type: Tokenizer.TokenType, value: ByteString?, filePosition: FileScanner.Position) {

//      guard let value = type.defaultValue ?? value else { fatalError("Internal Error") }

      self.filePosition = filePosition

      self.type = type
      self.value = type.defaultValue ?? value

      // set the column position to the start of the token
      self.filePosition.column -= numericCast(value?.count ?? 0)
    }
  }
}

extension Tokenizer.Token {

  static func infer(_ partial: ByteString) -> Tokenizer.TokenType? {

    switch partial {
    case "(": return .openParentheses
    case ")": return .closeParentheses
    case "[": return .openBracket
    case "]": return .closeBracket
    case "{": return .openBrace
    case "}": return .closeBrace
    case "=": return .equals
    case ":": return .colon

    default:
      return nil
    }
  }
}

extension Tokenizer {

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

    case endOfStatement

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
      case .endOfStatement:   return ";"
      case .equals:           return "="
      case .colon:            return ":"
      case .hash:             return "#"

      default:                return nil
      }
    }
  }
}

/*
extension Lexer.Token: CustomStringConvertible {

  var description: String {

    switch self {
    case .openBrace: return "{"
    case .closeBrace: return "}"
    case .openParentheses: return "("
    case .closeParentheses: return "("

    case .singleQuote: return "'"
    case .doubleQuote: return "\""

    case .endOfStatement: return ";"

    case .equals: return "="
    case .hash: return "#"
    case .colon: return ":"

    //case .declaration(let declaration): return declaration.description
    case .hereString(let string): return string

    case .literal(let value): return value
    case .identifier(let name): return "'\(name)'"
    case .comment(_): return ""
    }
  }
}
*/
