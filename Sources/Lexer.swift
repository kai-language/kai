
import Darwin.C

/// Tokens that come out of the lex() function, intended as input to the parser.
enum LexicalToken {
  case assignment
  case nilLiteral
  case charLiteral(Character)
  case stringLiteral(String)
  case integerLiteral(Int)
  case floatingPointLiteral(Double)
  case boolLiteral(Bool)
  case keyword(String)
  case compilerDirective(String)
  case identifier(String)
  case scope([LexicalToken]) // { .... }
}

enum CompilerDirective: String {
  case run
}

enum LexicalExpression {

  enum Declaration {

    case constant
    case variable
    case procedure
    case structure
  }

  case assignment
  case declaration(Declaration)
}

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var reader: FileReader
  var lastChar: UTF8.CodeUnit?

  init(file path: String) throws {

    guard let reader = FileReader(file: path) else { throw Error.Reason.fileNotFound }
    self.reader = reader
  }

  mutating func lex(file path: String) throws -> [LexicalToken] {

    skip(upTo: newline)

    var tokens: [LexicalToken] = []

    defer { skipWhitespace() }

    return tokens
  }

  mutating func skipWhitespace() {

    while let byte = reader.next() {

      guard byte.isWhitespace else { continue }
      return
    }
  }

  mutating func skip(upTo char: UTF8.CodeUnit) {

    while let byte = reader.next() {

      guard byte == char else {
        lastChar = char
        return
      }

      continue
    }
  }

  mutating func assertFollowed(by expected: [UTF8.CodeUnit]) throws {

    for expected in expected {

      guard let char = reader.next() else { throw Error.Reason.endOfFile }
      guard char == expected else { throw Error.Reason.invalidLiteral }
    }
  }
}

extension Lexer {

  /// Tokens representing special syntax characters.
  enum Syntax {
    static let leftParentheses  : UTF8.CodeUnit = 0x28 // (
    static let rightParentheses : UTF8.CodeUnit = 0x29 // )
    static let leftBrace        : UTF8.CodeUnit = 0x7b // {
    static let rightBrace       : UTF8.CodeUnit = 0x7d // }
    static let singleQuote      : UTF8.CodeUnit = 0x27 // '
    static let doubleQuote      : UTF8.CodeUnit = 0x22 // "
    static let atSymbol         : UTF8.CodeUnit = 0x40 // @
    static let equals           : UTF8.CodeUnit = 0x3d // =
    static let hash             : UTF8.CodeUnit = 0x23 // #
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
