
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

    //case declaration(DeclarationType)

    case literal(String)
    case identifier(String)
    case comment(String)

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

      //case "struct": self = .declaration(.structure)

      default:
        return nil
      }
    }

    /*
    enum DeclarationType: ByteString {
      case structure = "struct"

      // TODO(vdka): Do we want to limit ourselves to Swift-esque semantics for variable declarations
      //  I think it is clearer but I am biased.

      //case constant = "let"
      //case variable = "var"
    }
    */
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

  static func requiresMatch(_ char: ByteString) -> ByteString? {

    switch Token(char) {
    case .openBrace?: return "}"
    case .openParentheses?: return ")"
    case .singleQuote?: return "'"
    case .doubleQuote?: return "\""

    default: return nil
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

    case (.singleQuote, .singleQuote): fallthrough
    case (.doubleQuote, .doubleQuote): fallthrough

    case (.equals, .equals): fallthrough
    case (.hash, .hash): fallthrough
    case (.colon, .colon): fallthrough

    case (.endOfStatement, .endOfStatement): fallthrough

    //case (.declaration(let l), .declaration(let r)): return l == r

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

    //case .declaration(let declaration): return declaration.description

    case .literal(let value): return value
    case .identifier(let name): return "'\(name)'"
    case .comment(_): return ""
    }
  }
}

