
struct Lexer {

  var scanner: FileScanner
  var partial: ByteString = ""

  init(scanner: FileScanner) {

    self.scanner = scanner
  }
}

extension Lexer {

  static func tokenize(_ input: File) throws -> [Token] {

    var lexer = Lexer(scanner: FileScanner(file: input))

    var tokens: [Lexer.Token] = []

    while let token = try lexer.getToken() {
      // print("\(input.name)(\(token.filePosition.line):\(token.filePosition.column)): \(token)")

      tokens.append(token)
    }

    return tokens
  }
}

extension Lexer {

  mutating func getToken() throws -> Token? {

    skipWhitespace()

    defer { partial.removeAll(keepingCapacity: true) }

    var currentNode = lexerGrammer

    var peeked = 0

    while let char = scanner.peek(aheadBy: peeked) {
      peeked += 1

      // if we have some sort of token where we need to perform a Lexing action then do that
      if let nextAction = currentNode[char]?.value?.nextAction {

          return try nextAction(&self)()
      }

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[char] else {

        if let tokenType = currentNode.value {
          scanner.pop(peeked)
          return token(tokenType, value: partial)
        } else {

          consumeIdentifier()
          return token(.identifier, value: partial)
        }
      }

      // If the next node has no further children then it's a leaf.
      guard !nextNode.children.isEmpty else {
        scanner.pop(peeked)
        return token(nextNode.value!, value: partial)
      }

      /*
      if let tokenType = nextNode.tokenType, whitespace.contains(scanner.peek(aheadBy: peeked) ?? " ") {

        scanner.pop(peeked)
        return token(tokenType, value: partial)
      }
      */

      currentNode = nextNode
    }

    return nil
  }

  /// - Precondition: Scanner should be on the first character in an identifier
  mutating func consumeIdentifier() {

    let firstChar = scanner.pop()

    partial.append(firstChar)

    while let char = scanner.peek() {
      guard
        ("0"..."9").contains(char) ||
        ("a"..."z").contains(char) ||
        ("A"..."Z").contains(char)
        else { return }

      partial.append(char)
      scanner.pop()
    }
  }

  /// appends the contents of everything consumed to partial
  mutating func consumeWhile(_ predicate: (Byte) -> Bool) {

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

    let digits: CountableClosedRange<Byte> = "0"..."9"
    let alphaNumerics: Set<Byte> = Set("a"..."f", "A"..."F")

    let numberChars: Set<Byte>
    switch scanner.prefix(2) {
    case "0x": numberChars = Set(digits).union(alphaNumerics).union(["x", "_"])
    case "0b": numberChars = ["b", "0", "1", "_"]
    default:   numberChars = Set(digits).union([".", "_", "e", "E", "+", "-"])
    }

    /*
      Valid (floats)
      9.
      .6
      -.4
      2.99e8
      1.00e-5
      -.12e-5

      Invalid (floats)
      0.-1
      --01
    */

    var sightings = NumberParsingSightings(rawValue: 0)

    while let char = scanner.peek(), numberChars.contains(char) {

      switch char {
      case "-", "+":

        if sightings.contains(.decimal) && !sightings.contains(.exponent) {

          throw Error(.invalidLiteral, "Cannot provide a negative component for the mantisa")
        } else if sightings.contains(.exponentSign) {

          throw Error(.invalidLiteral, "Too many signs in exponent")
        } else if sightings.contains(.exponent) {

          sightings.insert(.exponentSign)
        }

      case ".":

        guard !sightings.contains(.decimal) else {
          throw Error(.invalidLiteral, "Too many decimal points in number")
        }
        sightings.insert(.decimal)

      case "e", "E":

        guard !sightings.contains(.exponent) else { throw Error(.invalidLiteral, "Too many exponent characters") }
        sightings.insert(.exponent)

      case digits:

        if sightings.contains(.decimal) && !sightings.contains(.exponent) {
          sightings.insert(.decimalDigit)
        } else if sightings.contains(.exponent) {
          sightings.insert(.exponentDigit)
        }

      default:
        break
      }
      partial.append(char)
      scanner.pop()
    }

    return token(sightings.indicatesReal ? .real : .integer, value: partial)
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
      self.message = message ?? "Add an error message"
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

struct NumberParsingSightings: OptionSet {
  let rawValue: UInt8
  init(rawValue: UInt8) { self.rawValue = rawValue }

  static let none           = NumberParsingSightings(rawValue: 0b0000_0000)
  static let decimal        = NumberParsingSightings(rawValue: 0b0000_0001)
  static let decimalDigit   = NumberParsingSightings(rawValue: 0b0000_0010)
  static let exponent       = NumberParsingSightings(rawValue: 0b0000_0100)
  static let exponentSign   = NumberParsingSightings(rawValue: 0b0000_1000)
  static let exponentDigit  = NumberParsingSightings(rawValue: 0b0001_0000)

  var indicatesReal: Bool {
    return self.rawValue != 0
  }
}



extension Lexer.Error {

  static let unknown = Reason.unknown
}
