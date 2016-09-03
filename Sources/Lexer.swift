
import func Darwin.C.isspace

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var scanner: FileScanner
  var partial: ByteString = ""

  init(scanner: FileScanner) {

    self.scanner = scanner
  }

  mutating func skipWhitespace() {

    while let char = scanner.peek(), whitespace.contains(char) {
      scanner.pop()
    }
  }

  mutating func getToken() throws -> Token {

    skipWhitespace()

    defer { partial.bytes.removeAll(keepingCapacity: true) }

    while let char = scanner.peek() {
      partial.append(char)

      switch partial {
      case "/":
        partial.bytes.removeAll()
        return try parseSolidus()

      case "=":
        scanner.pop()
        return token(.equals)

      case "+":
        scanner.pop()
        return token(.plus)

      case "-":
        scanner.pop()
        return token(.minus)

      case "*":
        scanner.pop()
        return token(.asterisk)

      case "\"":
        partial.bytes.removeAll()
        return try parseString()
        
      case _ where numbers.contains(partial.bytes.first!):
        return try parseNumber()

      case "var":
        scanner.pop()
        return try parseIdentifier()

      default:

        scanner.pop()
      }
    }

    return token(.endOfStream, value: partial)
  }
}


// MARK: - Parser

extension Lexer {

  mutating func parseSolidus() throws -> Token {
    assert(scanner.peek() == "/")

    switch scanner.peek(aheadBy: 1) {
    case "/"?:

      scanner.pop(2)
      skipWhitespace()

      while let char = scanner.peek() {

        guard char != "\n" else {
          return token(.comment, value: partial)
        }

        partial.append(char)

        scanner.pop()
      }

      return token(.endOfStream)

    case "*"?:

      scanner.pop(2)
      skipWhitespace()

      var depth: UInt = 1
      while depth != 0, let char = scanner.peek() {

        if char == "*" && scanner.peek(aheadBy: 1) == "/" {
          depth -= 1
        }

        partial.append(char)
        scanner.pop()
      }

      partial.bytes.removeLast(2)

      scanner.pop()

      return token(.comment, value: partial)

    // TODO(vdka): divisor
    default:
      return token(.unknown)
    }
  }

  mutating func parseString() throws -> Token {
    assert(scanner.peek() == "\"")

    scanner.pop()

    while let char = scanner.peek() {

      switch char {
      case "\\":

        switch scanner.peek() {
        case "\""?:
          partial.append("\"")

        case "\\"?:
          partial.append("\\")

        default:
          throw Error.Reason.invalidEscape
        }

      case "\"":
        scanner.pop()
        return token(.string, value: partial)

      default:
        partial.append(char)
      }

      scanner.pop()
    }

    throw Error.unknown
  }

  mutating func parseNumber() throws -> Token {
    scanner.pop()

    while let char = scanner.peek(),
      numbers.contains(char) || char == "_" {

      partial.append(char)
      scanner.pop()
    }

    return token(.integer, value: partial)
  }

  mutating func parseIdentifier() throws -> Token {
    assert(partial == "let" || partial == "var")

    partial.bytes.removeAll(keepingCapacity: true)

    skipWhitespace()

    while let char = scanner.peek(), !whitespace.contains(char) {

      partial.append(char)
      scanner.pop()
    }

    return token(.identifier, value: partial)
  }
}

// MARK: - Helpers

extension Lexer {

  // convenience for generating tokens with context.
  func token(_ type: TokenType, value: ByteString? = nil) -> Token {

    return Token(type: type, value: value, filePosition: scanner.position)
  }
}


// MARK: - Error

extension Lexer {

  struct Error: Swift.Error {

    enum Reason: Swift.Error {
      case unknown
      case unmatchedToken(ByteString)
      case invalidUnicode
      case invalidLiteral
      case invalidEscape
      case fileNotFound
      case endOfFile
    }
  }
}

extension Lexer.Error {

  static let unknown = Reason.unknown
}
