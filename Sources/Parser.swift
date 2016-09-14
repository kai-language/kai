
struct Parser {

  var lexer: BufferedScanner<Lexer.Token>

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

    /// While we haven't exhaused the lexer of tokens
    while let next = parser.lexer.peek() {

      switch next.type {
      case .newline, .lineComment, .blockComment:
        parser.lexer.pop()
        continue

      default:
        let node = try parser.nextASTNode()
        fileNode.add(node)
      }
    }

    return fileNode
  }

  mutating func nextASTNode() throws -> AST.Node {

    var currentNode = parserGrammar

    var lastMatch: Action<Parser, AST.Node>? = nil

    var peeked = 0

    while let token = lexer.peek(aheadBy: peeked) {
      peeked += 1

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[token.type] else {

        if case .newline = token.type {
          continue
        }

        guard let nextAction = lastMatch else {
          throw Error(.invalidSyntax, "Fell off the Trie at \(token)")
        }

        defer { skipNewlines() }
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

  mutating func skipNewlines() {

    while let next = lexer.peek() {
      guard case .newline = next.type else { return }
      lexer.pop()
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
