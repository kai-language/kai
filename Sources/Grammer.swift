
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

    case literal(String)
    case identifier(String)
    case comment(String)

    init?(_ char: UTF8.CodeUnit) {

      switch char {
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

  static func isLiteral(_ chars: [UTF8.CodeUnit]) -> LiteralType? {
    precondition(!chars.isEmpty, "isLiteral(_:) only works on a non-empty sequence of chars")

    if numbers.contains(chars.first!) {
      guard chars.dropFirst().follows(rule: numbers.contains) else { return .number }
    }

    return nil
  }

  static func needsMatching(_ char: UTF8.CodeUnit) -> UTF8.CodeUnit? {

    switch Token(char) {
    case .openBrace?: return "}"
    case .openParentheses?: return ")"
    case .singleQuote?: return "'"
    case .doubleQuote?: return "\""

    default: return nil
    }
  }
}

extension Sequence {

  func follows(rule: (Iterator.Element) -> Bool) -> Bool {

    for item in self {
      guard rule(item) else { return false }
    }

    return true
  }
}

extension Lexer.Token: Equatable {

  static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {

    switch (lhs, rhs) {
    case (.openBrace, .openBrace): fallthrough
    case (.closeBrace, .closeBrace): fallthrough
    case (.openParentheses, .openParentheses): fallthrough
    case (.closeParentheses, .closeParentheses): fallthrough

    case (.singleQuote, .singleQuote): fallthrough
    case (.doubleQuote, .doubleQuote): fallthrough

    case (.equals, .equals): fallthrough
    case (.hash, .hash): fallthrough
    case (.colon, .colon): fallthrough

    case (.endOfStatement, .endOfStatement): fallthrough

    case (.comment(_), .comment(_)): // all comments are considered equal
      return true

    case (.identifier(let l), .identifier(let r)):
      return l == r

    default:
      return false
    }
  }
}

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

    case .literal(let value): return value
    case .identifier(let name): return "'\(name)'"
    case .comment(_): return ""
    }
  }
}

