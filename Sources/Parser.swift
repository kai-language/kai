
struct Parser {

  var scanner: BufferedScanner<Lexer.Token>
  var symbols = SymbolTable()

  init(_ lexer: Lexer) {
    self.scanner = BufferedScanner(lexer)
  }

  static func parse(_ lexer: Lexer) throws -> AST {

    var parser = Parser(lexer)

    guard let fileName = parser.scanner.peek()?.filePosition.fileName else {
      return AST.Node(.file(name: "TODO"))
    }

    // TODO(vdka): Handle adding actual file nodes.
    let fileNode = AST.Node(.file(name: ByteString(fileName)))

    parser.skipIgnored()

    while let token = parser.scanner.peek() {
      switch token.type {
      case .newline, .blockComment, .lineComment:
        parser.scanner.pop()
        continue

      default:
        break
      }

      let node = try parser.nextASTNode()

      fileNode.add(node)
    }

    return fileNode
  }

  mutating func nextASTNode() throws -> AST.Node {

    var currentNode = parserGrammar

    var lastMatch: Action<Parser, AST.Node>? = nil

    skipIgnored()

    var peeked = 0
    while let token = scanner.peek(aheadBy: peeked) {
      peeked += 1

      debug("Got token: \(token)")

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[token.type] else {

        if case .newline = token.type {
          continue
        }

        debug()

        guard let nextAction = lastMatch else {
          throw Error(.invalidSyntax, "Fell off the Trie at \(token)")
        }

        defer { skipIgnored() }
        return try nextAction(&self)()
      }

      currentNode = nextNode

      if let match = currentNode.value {
        lastMatch = match
      }
    }

    debug("Not sure what to do with \(scanner.pop())")


    return AST.Node(.unknown)
  }

  enum DeclarationType {
    case runTime
    case compileTime
  }

  mutating func parseDeclaration() throws -> AST.Node {

    let identifier = scanner.pop()

    expect(.identifier, from: identifier)
    let symbol: Symbol
    var flags: Declaration.Flag = []
    switch scanner.pop().type {
    case .declaration:
      symbol = Symbol(identifier.value, kind: .variable)

    case .staticDeclaration:
      symbol = Symbol(identifier.value, kind: .variable)
      flags = .compileTime

    case .colon:
      let typeName = scanner.pop()
      expect(.assign, from: scanner.pop())
      symbol = Symbol(identifier.value, kind: .variable, type: .other(identifier: typeName.value))

    default:
      debug()
      fatalError("We probably shouldn't end up here.")
    }

    symbols.insert(symbol)

    let rvalue = try parseExpression()

    switch rvalue.kind {
    case .integerLiteral(let value):
      symbol.types = [.integer(value)]

    case .stringLiteral(let value):
      symbol.types = [.string(value)]

    default: // leave the type information empty, it can be filled in a later pass
      break
    }

    let declaration = Declaration(symbol, flags: flags)

    print("declaration: \(declaration)")

    return AST.Node(.declaration(declaration))
  }

  mutating func parseExpression() throws -> AST.Node {
    unimplemented()
  }

  mutating func skipIgnored() {

    while let next = scanner.peek() {
      switch next.type {
      case .newline, .lineComment, .blockComment:
        scanner.pop()

      default:
        return
      }
    }
  }
}

// MARK: - Helpers

extension Parser {

  func expect(_ expected: Lexer.TokenType, from given: Lexer.Token) {
    guard expected == given.type else {
      preconditionFailure("Expectations Failed! Expected token of type \(expected), got token \(given)!")
    }
  }
}

extension Parser {

  struct Error: Swift.Error {

    var reason: Reason
    var message: String

    var file: StaticString
    var line: UInt

    init(_ reason: Reason, _ message: String? = nil, file: StaticString = #file, line: UInt = #line) {
      self.reason = reason
      self.message = message ?? "Add an error message"
      self.file = file
      self.line = line
    }

    enum Reason: Swift.Error {
      case unknown
      case missingReturnType
      case invalidSyntax
      case expectedCloseParentheses
      case loneIdentifier
    }
  }
}
