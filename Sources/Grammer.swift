
let keywords: Set<ByteString> = ["let", "var", "struct"]
let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]"
  ]


extension Lexer {

  enum Token {

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
    case hereString(ByteString)

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

      case _ where utf8.count > 1 &&
        utf8.first == "`" &&
        utf8.last == "`":
        self = .hereString(utf8)

      default:
        return nil
      }
    }
  }
}

extension Lexer {

  enum LiteralType {
    case number
    case string
    case character
    case boolean
    case null
  }

  static func isLiteral(_ chars: ByteString) -> LiteralType? {
    precondition(!chars.isEmpty, "isLiteral(_:) only works on a non-empty sequence of chars")

    if numbers.contains(chars.first!) {
      guard chars.dropFirst().follows(rule: numbers.contains) else { return .number }
    }

    return nil
  }
}

extension Lexer.Token: Equatable {

  static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {

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
