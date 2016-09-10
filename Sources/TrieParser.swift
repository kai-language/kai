
typealias Action<Input, Output> = (inout Input) -> () throws -> Output

var parserGrammar: Trie<[Lexer.TokenType], Action<TrieParser, AST.Node>> = {

  func just(node: AST.Node) -> (inout Parser) -> () throws -> AST.Node {

    return { _ in
      return {
        return node
      }
    }
  }

  var parserGrammar: Trie<[Lexer.TokenType], Action<TrieParser, AST.Node>> = Trie(key: .unknown)

  parserGrammar.insert(TrieParser.parseImport, forKeyPath: [.importKeyword, .string])
  parserGrammar.insert(TrieParser.parseReturnExpression, forKeyPath: [.returnKeyword])

  // this will end up being a `call_expr` node. (as it's called in Swift)
  // parserGrammar.insert(just(node: AST.Node(.unknown)), forKeyPath: [.identifier, .openParentheses])

  // `parseStaticDeclaration determines if the following value is a type name, `
  parserGrammar.insert(TrieParser.parseStaticDeclaration, forKeyPath: [.identifier, .staticDeclaration])

  return parserGrammar
}()

struct TrieParser {

  var scanner: Scanner<Lexer.Token>

  init(_ tokens: [Lexer.Token]) {
    self.scanner = Scanner(tokens)
  }

  static func parse(_ tokens: [Lexer.Token]) throws -> AST.Node {

    var parser = TrieParser(tokens)

    // TODO(vdka): Handle adding actual file nodes.
    let fileNode = AST.Node(.unknown)

    while let node = try parser.nextASTNode() {
      // print("\(input.name)(\(token.filePosition.line):\(token.filePosition.column)): \(token)")

      fileNode.children.append(node)
    }

    return fileNode
  }

  mutating func nextASTNode() throws -> AST.Node? {

    var currentNode = parserGrammar

    var lastMatch: Action<TrieParser, AST.Node>? = nil

    var peeked = 0

    while let token = scanner.peek(aheadBy: peeked) {
      peeked += 1

      // Ensure we can traverse our Trie to the next node
      guard let nextNode = currentNode[token.type] else {

        guard let nextAction = lastMatch else { throw Error(.invalidSyntax) }

        return try nextAction(&self)()
      }

      currentNode = nextNode

      if let match = currentNode.value {
        lastMatch = match
      }
    }

    throw Error(.invalidSyntax)
  }

  mutating func parseScope() throws -> AST.Node {

    unimplemented()
  }

  mutating func parseImport() throws -> AST.Node {
    assert(scanner.peek()?.type == .importKeyword)
    scanner.pop()

    let fileName = scanner.pop().value

    return AST.Node(.fileImport, value: fileName)
  }

  mutating func parseStaticDeclaration() throws -> AST.Node {

    let identifier = scanner.pop()
    scanner.pop()
    guard let next = scanner.peek() else { throw Error(.invalidSyntax) }

    switch next.type {
    case .string:
      return AST.Node(.string, value: next.value)

    case .integer:
      return AST.Node(.integer, value: next.value)

    case .real:
      return AST.Node(.real, value: next.value)

    case .openParentheses: // peek until we find the matching close, if the next tokenType after that is a '->' then we have a procedure, otherwise it's a tuple
      var peeked = 1
      while let next = scanner.peek(aheadBy: peeked) {
        defer { peeked += 1 }

        if case .closeParentheses = next.type {
          if case .returnOperator? = scanner.peek(aheadBy: peeked + 1)?.type {
            return try parseProcedure()
          } else {
            return try parseTuple()
          }
        }
      }

      throw Error(.invalidSyntax)

    case .structKeyword:
      return try parseStruct()

    case .enumKeyword:
      return try parseEnum()

    case .identifier:
      // will need to do a number of things.
      // Firstly if the Identifier is not a literal then we need to check to see if the value can be resolved @ compile time.
      // if the value cannot be resolved at compile time then this program is invalid. The error emitted would be:
      //   "Error: Runtime expresion in compile time declaration"
      // Is that clear?
      unimplemented()

    default:
      throw Error(.invalidSyntax)
    }
  }

  mutating func parseTuple() throws -> AST.Node {
    unimplemented()
  }

  mutating func parseStruct() throws -> AST.Node {
    unimplemented()
  }

  mutating func parseProcedure() throws -> AST.Node {

    _ = scanner.pop()
    scanner.pop() // ::
    let input = try parseTuple()
    print(input)

    // parseScope(context: .procedure)

    unimplemented()
  }

  mutating func parseEnum() throws -> AST.Node {
    unimplemented()
  }

  // TODO(vdka): proper implementation
  mutating func parseExpression() throws -> AST.Node {

    return AST.Node(.unknown)
    // unimplemented()
  }

  // - Precondition: Scanner's first token type *must* be a .returnKeyword
  mutating func parseReturnExpression() throws -> AST.Node {

    scanner.pop()

    let expressionNode = try parseExpression()

    return AST.Node(.returnStatement, children: [expressionNode])
  }

  mutating func parseTypeList(forceParens: Bool = false) throws -> AST.Node {

    let list = AST.Node(.typeList)

    guard let token = scanner.peek() else {
      throw Error(.invalidSyntax, "Expected Type")
    }

    switch token.type {
    case .identifier where !forceParens: // single argument
      scanner.pop()

      let node = AST.Node(.type, name: token.value)
      list.children.append(node)

      return list

    case .identifier where forceParens:
      throw Error(.invalidSyntax, "The arugment types of a procedure must be surrounded by parenthesis '()'")

    case .openParentheses: // multi argument

      return try parseTuple()
      scanner.pop()

      var wasComma = false
      while let token = scanner.peek() {

        if case .comma = token.type {
          guard wasComma else { throw Error(.invalidSyntax, "Duplicate comma") }
          wasComma = false
          scanner.pop()
          continue
        } else {
          wasComma = true
        }

        if case .closeParentheses = token.type {
          // guard !wasComma else { throw Error(.invalidSyntax, "Trailing comma in Type list") }
          scanner.pop()

          return list
        }

        guard case .identifier = token.type else {
          throw Error(.invalidSyntax, "Expected Type")
        }
        scanner.pop()

        let node = AST.Node(.type, name: token.value)

        list.children.append(node)
      }

    default:
      throw Error(.invalidSyntax)
    }

    throw Error(.unknown)
  }
}

extension TrieParser {

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
