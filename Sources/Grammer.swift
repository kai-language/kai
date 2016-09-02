
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
    var value: ByteString

    init(type: Lexer.TokenType, value: ByteString?, filePosition: FileScanner.Position) {

      guard let value = type.defaultValue ?? value else { fatalError("Expected ") }

      self.filePosition = filePosition

      self.type = type
      self.value = value

      // set the column position to the start of the token
      self.filePosition.column -= numericCast(value.count)
    }
  }
}

extension Lexer.Token {

  static func infer(_ partial: ByteString) -> Lexer.TokenType? {

    switch partial {
    case "(": return .openParentheses
    case ")": return .closeParentheses
    case "{": return .openBrace
    case "}": return .closeBrace
    case "=": return .equals
    case ":": return .colon

    case _ where keywords.contains(partial):
      return .keyword

    default:
      return nil
    }
  }
}

extension Lexer {

  enum TokenType {
    case openBrace
    case closeBrace
    case openParentheses
    case closeParentheses

    case doubleQuote
    case singleQuote

    case endOfStatement

    case equals
    case colon
    case hash

    case identifier
    case stringLiteral
    case literal
    case keyword
    case comment

    var defaultValue: ByteString? {

      switch self {
      case .openBrace:        return "{"
      case .closeBrace:       return "}"
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

  enum TokenValue {

    case openBrace
    case closeBrace
    case openParentheses
    case closeParentheses

    case doubleQuote
    case singleQuote

    case endOfStatement

    case equals
    case colon
    case hash

    case identifier(ByteString)
    case literal(ByteString)
    case keyword(ByteString)
    case comment(ByteString)

    init?(_ utf8: ByteString) {

      switch utf8 {
      case "{":  self = .openBrace
      case "}":  self = .closeBrace
      case "(":  self = .openParentheses
      case ")":  self = .closeParentheses

      case "'":  self = .singleQuote
      case "\"": self = .doubleQuote

      case "\n": self = .endOfStatement
      case ";":  self = .endOfStatement

      case "=":  self = .equals
      case "#":  self = .hash
      case ":":  self = .colon

      case _ where keywords.contains(utf8):
        self = .keyword(utf8)

      default:
        return nil
      }
    }
  }
}

extension Lexer.TokenValue: Equatable {

  static func == (lhs: Lexer.TokenValue, rhs: Lexer.TokenValue) -> Bool {

    switch (lhs, rhs) {
    case (.openBrace, .openBrace):                fallthrough
    case (.closeBrace, .closeBrace):              fallthrough
    case (.openParentheses, .openParentheses):    fallthrough
    case (.closeParentheses, .closeParentheses):  fallthrough

    case (.singleQuote, .singleQuote):  fallthrough
    case (.doubleQuote, .doubleQuote):  fallthrough

    case (.equals, .equals):  fallthrough
    case (.hash, .hash):      fallthrough
    case (.colon, .colon):    fallthrough

    case (.endOfStatement, .endOfStatement):
      return true

    case (.keyword(let l), .keyword(let r)): return l == r

    // all comments are considered equal
    case (.comment(_), .comment(_)): return true

    case (.identifier(let l), .identifier(let r)): return l == r

    default:
      return false
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
