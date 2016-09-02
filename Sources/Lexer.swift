
let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var scanner: FileScanner
  var partial: ByteString = ""

  init(scanner: FileScanner) {

    self.scanner = scanner
  }

  func requiresMatch(_ string: ByteString) -> ByteString? {

    switch string {
    case "{":  return "}"
    case "(":  return ")"
    case "'":  return "'"
    case "\"": return "\""

    default: return nil
    }
  }

  mutating func parseString(terminator: ByteString) throws -> Token {

    assert(scanner.peek() == "\"")
    scanner.pop()

    repeat {

      let byte: UTF8.CodeUnit
      do {
        byte = try scanner.attemptPop()
      } catch {
        throw Error.Reason.unmatchedToken(terminator)
      }

      partial.bytes.append(byte)

      if partial.hasSuffix(terminator) {
        partial.bytes.removeLast(terminator.count)
        defer { partial.bytes.removeAll(keepingCapacity: true) }
        return token(type: .stringLiteral, value: partial)
      }
    } while true
  }

  // splits the input stream into whitespace seperated strings
  mutating func tokenize() throws -> [Token] {

    var tokens: [Token] = []
    while let byte = scanner.peek() {

      switch byte {
      case "\"":

        let stringLiteral = try parseString(terminator: "\"")
        tokens.append(stringLiteral)

      case _ where whitespace.contains(byte):

        // let tokenType = Token.infer(partial)

        print(partial)
        partial.bytes.removeAll(keepingCapacity: true)

      default:

        partial.bytes.append(scanner.pop())
        break
      }

      scanner.pop()

    }

    print(partial)
    return tokens
  }
}

extension Lexer {

  // convenience for generating tokens with context.
  func token(type: TokenType, value: ByteString? = nil) -> Token {

    return Token(type: type, value: value, filePosition: scanner.position)
  }
}

extension Lexer {

  struct Error: Swift.Error {

    enum Reason: Swift.Error {
      case unmatchedToken(ByteString)
      case invalidUnicode
      case invalidLiteral
      case fileNotFound
      case endOfFile
    }
  }
}
