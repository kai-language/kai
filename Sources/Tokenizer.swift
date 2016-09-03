
import func Darwin.C.isspace

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Tokenizer {

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

    switch scanner.peek() {
    case "/"?:
      switch scanner.peek(aheadBy: 1) {
      case "/"?:

        scanner.pop(2)

        while let char = scanner.peek() {

          guard char != "\n" else {
            return token(type: .comment, value: partial)
          }

          partial.append(char)

          scanner.pop()
        }

        return token(type: .endOfStream)

      case "*"?:

        scanner.pop(2)

        var depth: UInt = 1
        while depth != 0, let char = scanner.peek() {

          if char == "*" && scanner.peek(aheadBy: 1) == "/" {
            depth -= 1
          }

          partial.append(char)
        }

        partial.bytes.removeLast(2)

        return token(type: .comment, value: partial)

      default:
        return token(type: .unknown)
      }

    case "\""?:

      scanner.pop()

      var escaped = false

      while let char = scanner.peek() {

        defer { scanner.pop() }

        if char == "\\" {

          if escaped {
            partial.append("\\")
          } else {
            escaped = true
          }
          continue
        }

        if char == "\"" {
          if escaped {
            partial.append("\"")
          } else {
            partial
          }
        }
        if char == "\"" && !escaped {
          return token(type: .string, value: partial)
        }

        partial.append(char)

        scanner.pop()
      }

      throw Error.Reason.unknown

    case nil:
      return token(type: .endOfStream)

    default:
      scanner.pop()
      return token(type: .unknown)
    }
  }
}

extension Tokenizer {

  // convenience for generating tokens with context.
  func token(type: TokenType, value: ByteString? = nil) -> Token {

    return Token(type: type, value: value, filePosition: scanner.position)
  }
}

extension Tokenizer {

  struct Error: Swift.Error {

    enum Reason: Swift.Error {
      case unknown
      case unmatchedToken(ByteString)
      case invalidUnicode
      case invalidLiteral
      case fileNotFound
      case endOfFile
    }
  }
}
