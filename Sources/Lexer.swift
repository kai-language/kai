
let whitespace = Set([space, tab])

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var scanner: ByteScanner
  var lastChar: UTF8.CodeUnit? = nil
  var tokens: [Syntax] = []

  init(file: File) throws {

    let bytes = Array(file)

    self.scanner = try ByteScanner(bytes)
  }

  // splits the input stream into whitespace seperated strings
  mutating func tokenize() throws -> [Token] {

    var tokens: [Token] = []

    var identifierBuffer: [UTF8.CodeUnit] = []

    repeat {

      /// when we run out of byte return the tokens

      // TODO(vdka): input the final token
      guard let char = scanner.peek() else {

        if !identifierBuffer.isEmpty {
          guard let identifier = String(utf8: identifierBuffer) else { throw Error.Reason.invalidUnicode }
          tokens.append(.identifier(identifier))
        }
        return tokens
      }

      defer { scanner.pop() }

      if let token = Token(char: char) {
        if case .newline = token {
          // will strip the first newline but it's semantically meaningless
          guard let previous = tokens.last else { continue }
          guard previous != .newline else { continue }
          tokens.append(.newline)

          continue
        }
        tokens.append(token)
        continue
      }

      if char.isMember(of: whitespace) {
        guard let identifier = String(utf8: identifierBuffer) else { throw Error.Reason.invalidUnicode }

        tokens.append(.identifier(identifier))

        identifierBuffer.removeAll(keepingCapacity: true)
        continue
      }

      identifierBuffer.append(char)

    } while true
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
      case invalidUnicode
      case invalidLiteral
      case fileNotFound
      case endOfFile
    }
  }
}

extension UTF8.CodeUnit {

  func isMember(of set: Set<UTF8.CodeUnit>) -> Bool {
    return set.contains(self)
  }
}

