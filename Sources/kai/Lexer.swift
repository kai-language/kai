
let digits      = Array<Byte>("1234567890".utf8)
let opChars     = Array<Byte>("~!%^&*-+=<>|?".utf8)
let identChars  = Array<Byte>("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)
let whitespace  = Array<Byte>(" \t\n".utf8)


struct Lexer {

  var scanner: FileScanner
  var buffer: [Token] = []

  var filePosition: FileScanner.Position { return scanner.position }

  init(_ file: File) {

    self.scanner = FileScanner(file: file)
  }

  mutating func peek(aheadBy n: Int = 0) throws -> Token? {
    guard buffer.count <= n else { return buffer[n] }

    guard let token = try next() else { return nil }

    buffer.append(token)

    return token
  }

  @discardableResult
  mutating func pop() throws -> Token {
    if buffer.isEmpty { return try next()! }
    else { return buffer.removeFirst() }
  }

  mutating func next() throws -> Token? {
    try skipWhitespace()

    guard let char = scanner.peek() else { return nil }

    switch char {
    case _ where identChars.contains(char):
      let symbol = consume(with: identChars)
      if let keyword = Token.Keyword(rawValue: symbol) { return .keyword(keyword) }
      else { return .identifier(symbol) }

    case _ where opChars.contains(char):
      let symbol = consume(with: opChars)
      if let keyword = Token.Keyword(rawValue: symbol) { return .keyword(keyword) }
      else { return .operator(symbol) }

      // TODO(vdka): Correctly consume (and validate) number literals (real and integer)
    case _ where digits.contains(char):
      let number = consume(with: digits)
      return .integer(number)

    case "(":
      consume(with: "(")
      return .lparen

    case ")":
      consume(with: ")")
      return .rparen

    case "{":
      scanner.pop()
      return .lbracket

    case "}":
      scanner.pop()
      return .rbracket

    case ":":
      let symbol = consume(with: ":=")

      if symbol == ":=" { return .keyword(.declaration) }
      else if symbol == "::" { return .keyword(.compilerDeclaration) }
      else if symbol == ":" { return .colon }
      else { return nil } // TODO(vdka): Iterator here has the weakness of being non throwing

    case ",":
      consume(with: ",")
      return .comma

    default:
      let suspect = consume(upTo: whitespace.contains)

      throw error(.invalidToken(suspect), message: "The token \(suspect) is unrecognized")
    }
  }

  @discardableResult
  mutating func consume(with chars: [Byte]) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), chars.contains(char) {
      scanner.pop()
      str.append(char)
    }

    return str
  }

  @discardableResult
  mutating func consume(with chars: ByteString) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), chars.bytes.contains(char) {
      scanner.pop()
      str.append(char)
    }

    return str
  }

  @discardableResult
  mutating func consume(upTo predicate: (Byte) -> Bool) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), predicate(char) {
      scanner.pop()
      str.append(char)
    }

    return str
  }
}

extension Lexer {

  mutating func skipWhitespace() throws {
    while let char = scanner.peek() {

      switch char {
      case "/":
        if scanner.peek(aheadBy: 1) == "*" { try skipBlockComment() }
        else if scanner.peek(aheadBy: 1) == "/" { skipLineComment() }

      case _ where whitespace.contains(char):
        scanner.pop()

      default: return
      }
    }
  }

  mutating func skipBlockComment() throws {
    assert(scanner.hasPrefix("/*"))

    var depth: UInt = 0
    repeat {

      guard scanner.peek() != nil else {
        throw error(.unmatchedBlockComment)
      }

      if scanner.hasPrefix("*/") { depth -= 1 }
      else if scanner.hasPrefix("/*") { depth += 1 }

      scanner.pop()

      if depth == 0 { break }
    } while depth > 0
    scanner.pop()
  }

  mutating func skipLineComment() {
    assert(scanner.hasPrefix("//"))

    while let char = scanner.peek(), char != "\n" { scanner.pop() }
  }
}

extension Lexer {

  func error(_ reason: Error.Reason, message: String? = nil) -> Swift.Error {
    return Error(reason: reason, message: message, filePosition: scanner.position)
  }

  struct Error: CompilerError {


    var reason: Reason
    var message: String?
    var filePosition: FileScanner.Position
    
    enum Reason {
      case unmatchedBlockComment
      case invalidToken(ByteString)
      case unmatchedToken(Token)
      case invalidCharacter(Byte)
    }
  }
}
