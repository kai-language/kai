
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
      // partial.append(char)

      // if we have some sort of token where we need to perform a Lexing action then do that
      if let nextAction = currentNode[char]?.tokenType?.nextAction {

        return try nextAction(&self)()
      }

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[char] else {

        if let tokenType = currentNode.tokenType, whitespace.contains(scanner.peek(aheadBy: peeked + 1) ?? " ") {
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

    var depth: UInt = 1
    while let char = scanner.peek(), depth != 0 {

      if char == "*" && scanner.peek(aheadBy: 1) == "/" {
        depth -= 1
      }

      partial.append(char)
      scanner.pop()
    }

    // I beleive this means we have an unmatched '/*' token
    guard depth == 0 else { throw Error.unknown }

    partial.append(scanner.pop())

    return token(.blockComment, value: partial)
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
