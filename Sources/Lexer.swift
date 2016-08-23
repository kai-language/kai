
import Darwin.C

let whitespace = Set([space, tab, newline])

enum SyntaxToken {
  case openSqaure
  case closeBrace
  case newline
  case equals
  case openParentheses
  case closeParentheses
  case hash
  case identifier(String)
  case comment(String)
}

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var scanner: ByteScanner
  var lastChar: UTF8.CodeUnit? = nil
  var tokens: [Syntax] = []

  init(file: File) {

    self.scanner = ByteScanner(bytes: file)
  }

  // splits the input stream into whitespace seperated strings
  mutating func tokenize() -> [String] {

    var tokens: [String] = []

    while let tokenBytes = scanner.consume(to: whitespace.contains) {
      guard !tokenBytes.isEmpty else { continue }
      guard let string = String(utf8: tokenBytes) else { fatalError("Invalid Unicode") }
      tokens.append(string)
    }

    return tokens
  }

  func parseNext(byte: UTF8.CodeUnit) {

  }
}

extension Lexer {

  /// Tokens representing special syntax characters.
  enum Syntax: UTF8.CodeUnit {
    case openParentheses  = 0x28 // (
    case closeParentheses = 0x29 // )
    case openBrace        = 0x7b // {
    case closeBrace       = 0x7d // }
    case singleQuote      = 0x27 // '
    case doubleQuote      = 0x22 // "
    case atSymbol         = 0x40 // @
    case equals           = 0x3d // =
    case hash             = 0x23 // #
  }
}

extension Lexer {

  struct Error: Swift.Error {

    enum Reason: Swift.Error {
      case invalidLiteral
      case fileNotFound
      case endOfFile
    }
  }
}
