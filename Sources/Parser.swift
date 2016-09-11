
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

  parserGrammar.insert(Parser.parseImport,            forKeyPath: [.importKeyword, .string])
  parserGrammar.insert(Parser.parseReturnExpression,  forKeyPath: [.returnKeyword])
  parserGrammar.insert(Parser.parseScope,             forKeyPath: [.openBrace])

  parserGrammar.insert(Parser.parseCall,              forKeyPath: [.identifier, .openParentheses])

  // this will end up being a `call_expr` node. (as it's called in Swift)
  // parserGrammar.insert(just(node: AST.Node(.unknown)), forKeyPath: [.identifier, .openParentheses])

  // `parseStaticDeclaration determines if the following value is a type name, `
  parserGrammar.insert(Parser.parseStaticDeclaration, forKeyPath: [.identifier, .staticDeclaration])

  return parserGrammar
}()

struct Parser {

  var scanner: Scanner<Lexer.Token>

  init(_ tokens: [Lexer.Token]) {
    self.scanner = Scanner(tokens)
  }

  static func parse(_ tokens: [Lexer.Token]) throws -> AST.Node {

    var parser = Parser(tokens)

    guard let fileName = tokens.first?.filePosition.fileName else { return AST.Node(.emptyFile) }

    // TODO(vdka): Handle adding actual file nodes.
    let fileNode = AST.Node(.file, name: ByteString(fileName))

    // while !parser.scanner.isEmpty {
    while let next = parser.scanner.peek() {

      guard next.type != .newline else {
        parser.scanner.pop()
        continue
      }
      // print("\(input.name)(\(token.filePosition.line):\(token.filePosition.column)): \(token)")

      let node = try parser.nextASTNode()
      fileNode.children.append(node)
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

        guard let nextAction = lastMatch else { throw Error(.invalidSyntax) }

        defer { skipNewlines() }
        return try nextAction(&self)()
      }

      currentNode = nextNode

      if let match = currentNode.value {
        lastMatch = match
      }
    }

    return AST.Node(.unknown)
  }

  mutating func parseScope() throws -> AST.Node {
    precondition(scanner.pop().type == .openBrace)

    var scopeTokens: [Lexer.Token] = []

    var depth = 1
    while let next = scanner.peek() {
      switch next.type {
      case .openBrace:
        depth += 1

      case .closeBrace:
        depth -= 1

      default:
        break
      }

      guard depth > 0 else { break }

      scanner.pop()
      scopeTokens.append(next)
    }

    guard depth == 0 else { throw Error(.invalidSyntax, "Unmatched brace") }

    let scopeBody = try Parser.parse(scopeTokens)

    let scope = AST.Node(.scope, children: scopeBody.children)

    precondition(scanner.pop().type == .closeBrace)

    return scope
  }

  mutating func parseImport() throws -> AST.Node {
    assert(scanner.peek()?.type == .importKeyword)
    scanner.pop()

    let fileName = scanner.pop().value

    return AST.Node(.fileImport, value: fileName)
  }

  mutating func parseStaticDeclaration() throws -> AST.Node {

    var seen = 2

    guard let next = scanner.peek(aheadBy: seen) else { throw Error(.invalidSyntax) }
    seen += 1

    switch next.type {
    case .string:
      return parseStaticLiteral(.string)

    case .integer:
      return parseStaticLiteral(.string)

    case .real:
      return parseStaticLiteral(.string)

    case .openParentheses: // peek until we find the matching close, if the next tokenType after that is a '->' then we have a procedure, otherwise it's a tuple
      while let next = scanner.peek(aheadBy: seen) {
        defer { seen += 1 }

        if case .closeParentheses = next.type {
          if case .returnOperator? = scanner.peek(aheadBy: seen + 1)?.type {

            while case .newline? = scanner.peek()?.type {
              scanner.pop()
            }

            return try parseProcedure()
          } else {

            let nameToken = scanner.pop()
            let node = AST.Node(.staticDeclaration, name: nameToken.value)

            node.children = [try parseTuple()]

            return node
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

  mutating func parseStaticLiteral(_ kind: AST.Node.Kind) -> AST.Node {
    let identifier = scanner.pop()
    scanner.pop()
    let literal = scanner.pop()

    let value = AST.Node(kind, name: literal.value)

    return AST.Node(.staticDeclaration, name: identifier.value, children: [value])
  }

  mutating func parseTuple() throws -> AST.Node {
    let t = scanner.pop()
    precondition(t.type == .openParentheses, "\(t)")

    let tuple = AST.Node(.tuple)

    var wasComma = false
    while let token = scanner.peek() {

      if case .comma = token.type {
        guard !tuple.children.isEmpty else { throw Error(.invalidSyntax, "Trailing Comma") }
        guard !wasComma else { throw Error(.invalidSyntax, "Duplicate comma") }
        wasComma = true
        scanner.pop()
        continue
      }

      if case .closeParentheses = token.type {
        guard !wasComma else { throw Error(.invalidSyntax, "Trailing comma in Type list") }

        scanner.pop()

        return tuple
      }

      guard case .identifier = token.type else { throw Error(.invalidSyntax, "Expected Type") }
      scanner.pop()

      let type = AST.Node(.type, name: token.value)

      tuple.children.append(type)

      wasComma = false
    }

    throw Error(.invalidSyntax, "Expected ')' too match")
  }

  mutating func parseStruct() throws -> AST.Node {
    unimplemented()
  }

  mutating func parseProcedure() throws -> AST.Node {

    let identifier = scanner.pop()
    precondition(scanner.pop().type == .staticDeclaration) // ::
    let input = try parseTuple()
    scanner.pop() // ->

    let output = try parseType()

    let body = try parseScope()

    let procedure = AST.Node(.procedure, name: identifier.value, children: [input, output, body])

    return procedure


    // unimplemented()
  }

  mutating func parseEnum() throws -> AST.Node {
    unimplemented()
  }

  // TODO(vdka): proper implementation
  mutating func parseExpression() throws -> AST.Node {

    let next = scanner.peek()!

    switch next.type {
    case .string:
      scanner.pop()
      return AST.Node(.string, value: next.value)

    case .integer:
      scanner.pop()
      return AST.Node(.integer, value: next.value)

    case .real:
      scanner.pop()
      return AST.Node(.real, value: next.value)

    default:

      debug("Not yet sure what to do with a \(next) while parsing expression")
      break
    }

    return AST.Node(.unknown)
    // unimplemented()
  }

  // - Precondition: Scanner's first token type *must* be a .returnKeyword
  mutating func parseReturnExpression() throws -> AST.Node {

    scanner.pop()

    let expressionNode = try parseExpression()

    return AST.Node(.returnStatement, children: [expressionNode])
  }

  mutating func parseType() throws -> AST.Node {

    let list = AST.Node(.typeList)

    guard let token = scanner.peek() else {
      throw Error(.invalidSyntax, "Expected Type")
    }

    switch token.type {
    case .identifier: // single argument
      scanner.pop()

      let node = AST.Node(.type, name: token.value)
      list.children.append(node)

      return list

    case .openParentheses: // multi argument

      return try parseTuple()

    default:
      throw Error(.invalidSyntax)
    }
  }

  mutating func parseCall() throws -> AST.Node {

    guard let procedureName = scanner.peek()?.value else { throw Error(.invalidSyntax) }
    scanner.pop()
    guard case .openParentheses? = scanner.peek()?.type else { throw Error(.invalidSyntax) }
    scanner.pop()

    let call = AST.Node(.call, name: procedureName)

    var wasComma = false
    while let token = scanner.peek() {

      if case .comma = token.type {
        guard !call.children.isEmpty else { throw Error(.invalidSyntax, "Trailing Comma") }
        guard !wasComma else { throw Error(.invalidSyntax, "Duplicate comma") }
        wasComma = true
        scanner.pop()
        continue
      }

      if case .closeParentheses = token.type {
        guard !wasComma else { throw Error(.invalidSyntax, "Trailing comma in Type list") }

        scanner.pop()

        return call
      }

      let expression = try parseExpression()
      debug(expression)

      call.children.append(expression)

      wasComma = false
    }

    guard case .closeParentheses? = scanner.peek()?.type else { throw Error(.invalidSyntax) }
    scanner.pop()

    return call
  }

  mutating func skipNewlines() {

    while let next = scanner.peek() {
      guard case .newline = next.type else { return }
      scanner.pop()
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
