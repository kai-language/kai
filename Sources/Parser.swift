
typealias Action<Input, Output> = (inout Input) -> () throws -> Output

var parserGrammar: Trie<[Lexer.TokenType], Action<Parser, AST.Node>> = {

  func just(node: AST.Node) -> (inout Parser) -> () throws -> AST.Node {

    return { _ in
      return {
        return node
      }
    }
  }

  var parserGrammar: Trie<[Lexer.TokenType], Action<Parser, AST.Node>> = Trie(key: .unknown)

  // parserGrammar.insert(Parser.parseReturnExpression,  forKeyPath: [.returnKeyword])

  // parserGrammar.insert(Parser.parseCall,              forKeyPath: [.identifier, .openParentheses])

  // this will end up being a `call_expr` node. (as it's called in Swift)
  // parserGrammar.insert(just(node: AST.Node(.unknown)), forKeyPath: [.identifier, .openParentheses])

  // `parseStaticDeclaration determines if the following value is a type name, `
  // parserGrammar.insert(Parser.parseStaticDeclaration, forKeyPath: [.identifier, .staticDeclaration])

  return parserGrammar
}()

struct Parser {

  var scanner: Scanner<Lexer.Token>

  init(_ tokens: [Lexer.Token]) {
    self.scanner = Scanner(tokens)
  }

  static func parse(_ tokens: [Lexer.Token]) throws -> AST {

    var parser = Parser(tokens)

    guard let fileName = tokens.first?.filePosition.fileName else {
      return AST.Node(.file(name: "TODO"))
    }

    // TODO(vdka): Handle adding actual file nodes.
    let fileNode = AST.Node(.file(name: ByteString(fileName)))

    // while !parser.scanner.isEmpty {
    while let next = parser.scanner.peek() {

      switch next.type {
      case .newline, .lineComment, .blockComment:
        parser.scanner.pop()
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

    while let token = scanner.peek(aheadBy: peeked) {
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

    while let next = scanner.peek() {
      guard case .newline = next.type else { return }
      scanner.pop()
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
