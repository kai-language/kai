
let digits      = Array<Byte>("1234567890".utf8)
let opChars     = Array<Byte>("~!%^&*-+=<>|?".utf8)
let identChars  = Array<Byte>("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)
let whitespace  = Array<Byte>(" \t\n".utf8)


struct Lexer {

  var scanner: FileScanner
  var buffer: [Token] = []

  var sizeOfLastToken = 0

  var filePosition: FileScanner.Position {
    var scannerPosition = scanner.position
    scannerPosition.column -= numericCast(sizeOfLastToken)
    // let's hope we stay single line for all token's at least for now.
    return scannerPosition
  }

  init(_ file: File) {

    self.scanner = FileScanner(file: file)
  }

  // TODO(vdka): Something is wrong in here
  mutating func peek(aheadBy n: Int = 0) throws -> Token? {
    guard buffer.count <= n else { return buffer[n] }
    for _ in 0...n {
      guard let token = try next() else { return nil }
      buffer.append(token)
    }

    print("You peeking up \(n) gon get \(buffer.last!)")

    return buffer.last
  }

  @discardableResult
  mutating func pop() throws -> Token {
    let token: Token
    if buffer.isEmpty { token = try next()! }
    else { token = buffer.removeFirst() }

    switch token {
    case .colon, .comma, .equals, .lparen, .rparen, .lbrace, .rbrace:
      sizeOfLastToken = 1

    // FIXME(vdka): This code doesn't support Unicode length
    case .string(let str):
      sizeOfLastToken = str.bytes.count + 2

    case .integer(let val), .real(let val), .identifier(let val), .operator(let val):
      sizeOfLastToken = val.bytes.count

    case .keyword(.if), .keyword(.returnType):
      sizeOfLastToken = 2

    case .keyword(.enum), .keyword(.true), .keyword(.else):
      sizeOfLastToken = 4

    case .keyword(.false):
      sizeOfLastToken = 5

    case .keyword(.struct), .keyword(.return):
      sizeOfLastToken = 6

    case .directive(let directive):
      sizeOfLastToken = directive.rawValue.bytes.count + 1 // + 1 for the '#'
    }
    
    return token
  }

  internal mutating func next() throws -> Token? {
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
      else if symbol == "=" { return .equals }
      else { return .operator(symbol) }

    // TODO(vdka): Correctly consume (and validate) number literals (real and integer)
    case _ where digits.contains(char):
      let number = consume(with: digits)
      return .integer(number)

    case "\"":
      // TODO(vdka): calling consume here is stupid, it will consume all '"' character's in a row
      consume(with: "\"")
      let string = consume(upTo: "\"")
      // FIXME(vdka): This code has a bug, when a string is not terminated. I think.
      consume(with: "\"")
      return .string(string)

    case "(":
      scanner.pop()
      return .lparen

    case ")":
      scanner.pop()
      return .rparen

    case "{":
      scanner.pop()
      return .lbrace

    case "}":
      scanner.pop()
      return .rbrace

    case ":":
      scanner.pop()
      return .colon

    case ",":
      scanner.pop()
      return .comma

    case "#":
      scanner.pop()
      let identifier = consume(upTo: { !whitespace.contains($0) })
      guard let directive = Token.Directive(rawValue: identifier) else {
        throw error(.unknownDirective, message: "The directive '\(identifier)' is unknown!")
      }

      return .directive(directive)

    default:
      let suspect = consume(upTo: whitespace.contains)

      throw error(.invalidToken(suspect), message: "The token \(suspect) is unrecognized")
    }
  }

  @discardableResult
  private mutating func consume(with chars: [Byte]) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), chars.contains(char) {
      scanner.pop()
      str.append(char)
    }

    return str
  }

  @discardableResult
  private mutating func consume(with chars: ByteString) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), chars.bytes.contains(char) {
      scanner.pop()
      str.append(char)
    }

    return str
  }

  @discardableResult
  private mutating func consume(upTo predicate: (Byte) -> Bool) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), predicate(char) {
      scanner.pop()
      str.append(char)
    }
    return str
  }

  @discardableResult
  private mutating func consume(upTo target: Byte) -> ByteString {

    var str: ByteString = ""
    while let char = scanner.peek(), char != target {
      scanner.pop()
      str.append(char)
    }
    return str
  }

}

extension Lexer {

  fileprivate mutating func skipWhitespace() throws {
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

  private mutating func skipBlockComment() throws {
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

  private mutating func skipLineComment() {
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

    enum Reason: Swift.Error {
      case unknownDirective
      case unmatchedBlockComment
      case invalidToken(ByteString)
      case unmatchedToken(Token)
      case invalidCharacter(Byte)
    }
  }
}
