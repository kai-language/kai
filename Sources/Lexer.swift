
struct Lexer {

  var scanner: FileScanner
  var partial: ByteString = ""

  init(scanner: FileScanner) {

    self.scanner = scanner
  }
}

extension Lexer {

  mutating func getToken() throws -> Token {

    skipWhitespace()

    defer { partial.removeAll(keepingCapacity: true) }

    var currentNode = grammer.root

    var peeked = 0

    while let char = scanner.peek(aheadBy: peeked) {
      peeked += 1

      // if we have some sort of token where we need to perform a Lexing action then do that
      if let nextAction = currentNode[char]?.tokenType?.nextAction {

        return try nextAction(&self)()
      }

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[char] else {

        if let tokenType = currentNode.tokenType, whitespace.contains(char) {
          scanner.pop(peeked)
          return token(tokenType, value: partial)
        } else {

          consumeWhile({ !whitespace.contains($0) })
          return token(.identifier, value: partial)
        }
      }

      // If the next node has no further children then it's a leaf.
      guard !nextNode.children.isEmpty else {
        // print("popping \(peeked)")
        scanner.pop(peeked)
        return token(nextNode.tokenType!, value: partial)
      }

      /*
      if let tokenType = nextNode.tokenType, whitespace.contains(scanner.peek(aheadBy: peeked) ?? " ") {

        scanner.pop(peeked)
        return token(tokenType, value: partial)
      }
      */


      currentNode = nextNode
    }

    return token(.endOfStream, value: partial)
  }

  /// appends the contents of everything consumed to partial
  mutating func consumeWhile(_ predicate: (FileScanner.Byte) -> Bool) {

    while let char = scanner.peek(), predicate(char) {
      partial.append(char)
      scanner.pop()
    }
  }
}

extension Lexer {

  mutating func skipWhitespace() {

    while let char = scanner.peek(), whitespace.contains(char) {
      scanner.pop()
    }
  }

  mutating func parseString() throws -> Token {
    assert(scanner.peek() == "\"")
    partial.removeAll()
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

    // TODO(vdka): Do float stuff

    let digits: Set<ByteString.Byte> = Set("0"..."9")
    let alphaNumerics: Set<ByteString.Byte> = Set("a"..."f", "A"..."F")

    let numberChars: Set<ByteString.Byte>
    switch scanner.prefix(2) {
    case "0x": numberChars = digits.union(alphaNumerics).union(["x", "_"])
    case "0b": numberChars = Set(["b", "0", "1", "_"])
    default:   numberChars = digits.union([".", "_"])
    }

    while let char = scanner.peek(), numberChars.contains(char) {

      partial.append(char)
      scanner.pop()
    }

    return token(.number, value: partial)
  }

  mutating func parseBlockComment() throws -> Token {
    assert(scanner.hasPrefix("/*"))

    let startPosition = scanner.position

    var depth: UInt = 0
    repeat {

      guard let char = scanner.peek() else {
        throw Error(.unmatchedToken, "Missing match block comment's not matched")
      }

      if scanner.hasPrefix("*/") {

        depth -= 1
      } else if scanner.hasPrefix("/*") {

        depth += 1
      }

      partial.append(char)
      scanner.pop()

      if depth == 0 { break }
    } while depth > 0

    // I beleive this means we have an unmatched '/*' token
    guard depth == 0 else { throw Error(.unmatchedToken) }

    partial.append(scanner.pop())

    return Token(type: .blockComment, value: partial, filePosition: startPosition)
  }

  mutating func parseLineComment() throws -> Token {
    assert(scanner.hasPrefix("//"))

    while let char = scanner.peek(), char != "\n" {

      partial.append(char)
      scanner.pop()
    }

    return token(.lineComment, value: partial)
  }
}


// MARK: - Helpers

extension Lexer {

  /// - Precondition: Multiline tokens must have their position specified
  func token(_ type: TokenType, value: ByteString? = nil) -> Token {

    var position = scanner.position

    position.column -= numericCast(type.defaultValue?.count ?? value?.count ?? 0)

    return Token(type: type, value: value, filePosition: position)
  }

  /// - Note: This is really just here for consistency
  func token(_ type: TokenType, value: ByteString, position: FileScanner.Position) -> Token {
    return Token(type: type, value: value, filePosition: position)
  }
}


// MARK: - Error

extension Lexer {

  struct Error: Swift.Error {

    var reason: Reason
    var message: String

    init(_ reason: Reason, _ message: String? = nil) {
      self.reason = reason
      self.message = "Add an error message"
    }

    enum Reason: Swift.Error {
      case unknown
      case unmatchedToken
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
