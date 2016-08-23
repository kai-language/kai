
extension Lexer {

  enum Token {

    case openBrace
    case closeBrace
    case openParentheses
    case closeParentheses
    case newline
    case equals
    case hash
    case colon
    case identifier(String)
    case comment(String)

    init?(char: UTF8.CodeUnit) {

      switch char {
      case "{":  self = .openBrace
      case "}":  self = .closeBrace
      case "(":  self = .openParentheses
      case ")":  self = .closeParentheses
      case "\n": self = .newline
      case "=":  self = .equals
      case "#":  self = .hash
      case ":":  self = .colon

      default:
        return nil
      }
    }
  }
}

extension Lexer.Token: Equatable {

  static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {

    switch (lhs, rhs) {
    case (.openBrace, .openBrace): fallthrough
    case (.closeBrace, .closeBrace): fallthrough
    case (.openParentheses, .openParentheses): fallthrough
    case (.closeParentheses, .closeParentheses): fallthrough
    case (.equals, .equals): fallthrough
    case (.hash, .hash): fallthrough
    case (.colon, .colon): fallthrough
    case (.newline, .newline): fallthrough
    case (.comment(_), .comment(_)): // all comments are considered equal
      return true

    case (.identifier(let l), .identifier(let r)):
      return l == r

    default:
      return false
    }
  }
}

