
// MARK: - Parser
// AKA Semantic checker
// This component validates that the program structure is actually correct.
// IE: Is a token of type N followed by a token of type M valid?

struct Parser {

  var scanner: Scanner<Lexer.Token>

  init(_ tokens: [Lexer.Token]) {
    self.scanner = Scanner(tokens)
  }

  mutating func parse() throws -> AST.Node {

    while let token = scanner.peek() {

      switch token.type {
      case .identifier:
        scanner.pop()

        return try parseIdentifier(named: token.value)

      case .returnKeyword:
        scanner.pop()

        // TODO(vdka): Ensure return type is what is expected
        let node = AST.Node(.returnStatement)

        return node

      case .integer:
        scanner.pop()

        let node = AST.Node(.integer, value: token.value)

        return node

      default:
        scanner.pop()
        break
      }
    }

    return AST.Node(.unknown)
  }

  mutating func parseIdentifier(named name: ByteString) throws -> AST.Node {

    guard let next = scanner.peek() else { throw Error.Reason.loneIdentifier }

    switch next.type {
    case .declaration, .assignment:
      unimplemented()


    case .staticDeclaration:
      scanner.pop()

      switch scanner.peek()?.type {
      case .structKeyword?, .enumKeyword?:
        unimplemented()

      case .openParentheses?:

        let inputTypes = try parseTypeList(forceParens: true)

        guard case .returnOperator = try scanner.attemptPop().type else {
          throw Error(.invalidSyntax, "Missing return symbol '->'")
        }

        let outputTypes = try parseTypeList()

        guard case .openBrace? = scanner.peek()?.type else {
          throw Error(.invalidSyntax, "Missing open brace after procedure declaration")
        }

        let procedureBody = try parseScope()

        let node = AST.Node(.procedure, name: name)
        node.children = [inputTypes, outputTypes, procedureBody]

        return node

      default:
        // TODO(vdka): `Type` is ambiguous here how do you refer to language
        //  level constructs like procedures, structs, enums, unions etc.
        throw Error(.invalidSyntax, "Expected a Type name after static declaration")
      }

    default:
      break
//      throw Error(.invalidSyntax, "Expected")
    }

    return AST.Node(.unknown)
  }

  // TODO(vdka): Support the following form: Also support multiple return values in general
  /*
  someFunc :: (Int, Int) -> (Int, Int)
  */
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
      throw Error(.invalidSyntax, "The arugment types of a proc must be surrounded by parenthesis '()'")

    case .openParentheses: // multi argument
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

  mutating func parseScope() throws -> AST.Node {

    assert(scanner.peek()?.type == .openBrace)

    //TODO(vdka): maybe crashes on main :: () -> Int EOF
    scanner.pop()

    let scopeNode = AST.Node(.scope)

    repeat {

      let node = try parse()

      scopeNode.children.append(node)

    } while scanner.peek() != nil && scanner.peek()?.type != .closeBrace

    return scopeNode
  }

  mutating func parseImport() throws -> AST.Node {
    assert(scanner.peek()?.type == .importKeyword)
    scanner.pop()

    let fileName = scanner.pop().value

    return AST.Node(.fileImport, value: fileName)
  }

  mutating func parseStruct() throws -> AST.Node {
    unimplemented()
  }

  mutating func parseProcedure() throws -> AST.Node {
    unimplemented()
  }

  mutating func parseEnum() throws -> AST.Node {
    unimplemented()
  }
}

extension Parser {

  struct Error: Swift.Error {

    var reason: Reason
    var message: String

    init(_ reason: Reason, _ message: String? = nil) {
      self.reason = reason
      self.message = message ?? "Add an error message"
    }

    enum Reason: Swift.Error {
      case unknown
      case missingReturnType
      case invalidSyntax
      case loneIdentifier
    }
  }
}
