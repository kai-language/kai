
struct Parser {

  var lexer: BufferedScanner<Lexer.Token>
  var symbols = SymbolTable()

  init(_ lexer: Lexer) {
    self.lexer = BufferedScanner(lexer)
  }

  static func parse(_ lexer: Lexer) throws -> AST {

    var parser = Parser(lexer)

    guard let fileName = parser.lexer.peek()?.filePosition.fileName else {
      return AST.Node(.file(name: "TODO"))
    }

    // TODO(vdka): Handle adding actual file nodes.
    let fileNode = AST.Node(.file(name: ByteString(fileName)))

    parser.skipIgnored()

    while let token = parser.lexer.peek() {
      switch token.type {
      case .newline, .blockComment, .lineComment:
        parser.lexer.pop()
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
    while let token = lexer.peek(aheadBy: peeked) {
      peeked += 1

      debug("Got token: \(token)")

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[token.type] else {

        if case .newline = token.type {
          continue
        }

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

    debug("Something went wrong!")

    return AST.Node(.unknown)
  }

  enum DeclarationType {
    case runTime
    case compileTime
  }

  mutating func parseDeclaration() throws -> AST.Node {

    let identifier = lexer.pop()

    expect(.identifier, from: identifier)
    let symbol: Symbol
    var flags: Declaration.Flag = []
    switch lexer.pop().type {
    case .declaration:
      symbol = Symbol(identifier.value, kind: .variable)

    case .staticDeclaration:
      symbol = Symbol(identifier.value, kind: .variable)
      flags = .compileTime

    case .colon:
      let typeName = lexer.pop()
      expect(.assign, from: lexer.pop())
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

    return AST.Node(.declaration(declaration))
  }

  mutating func parseExpression() throws -> AST.Node {

    guard let token = lexer.peek() else { throw Error(.invalidSyntax, "Expected Expression!") }
    switch token.type {
    case .integer:
      lexer.pop()
      return AST.Node(.integerLiteral(token.value))

    case .string:
      lexer.pop()
      return AST.Node(.stringLiteral(token.value))

    case .real:
      lexer.pop()
      return AST.Node(.realLiteral(token.value))

    case .identifier:
      lexer.pop()
      return AST.Node(.identifier(token.value))

    default:
      unimplemented()
    }
  }

  mutating func skipIgnored() {

    while let next = lexer.peek() {
      switch next.type {
      case .newline, .lineComment, .blockComment:
        lexer.pop()

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
      case loneIdentifier
    }
  }
}
