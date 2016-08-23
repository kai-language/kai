
let whitespace = Set([space, tab, newline])

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  // splits the input stream into whitespace seperated strings
  mutating func tokenize(_ buffer: [UTF8.CodeUnit]) throws -> [Token] {

    guard !buffer.isEmpty else { return [] }


    var scanner: ByteScanner = try! ByteScanner(buffer)

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

      let token = Token(char: char)

      guard token != .newline else {
        if !identifierBuffer.isEmpty {
          tokens.append(contentsOf: try self.tokenize(identifierBuffer))
          identifierBuffer.removeAll(keepingCapacity: true)
        }

        guard let previous = tokens.last else { continue } // strips leading newlines
        if previous == .newline { continue }

        tokens.append(.newline)

        continue
      }

      if let token = token {

        tokens.append(token)
        continue
      }

      if char.isMember(of: whitespace) {

        guard !identifierBuffer.isEmpty else { continue }
        guard let identifier = String(utf8: identifierBuffer) else { throw Error.Reason.invalidUnicode }

        if Lexer.isLiteral(identifierBuffer) != nil {
          tokens.append(.literal(identifier))
        } else {

          tokens.append(.identifier(identifier))
        }

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

