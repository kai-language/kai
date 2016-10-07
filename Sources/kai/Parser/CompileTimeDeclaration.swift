
extension Parser {

  static func parseCompileTimeDeclaration(parser: inout Parser, lvalue: AST.Node) throws -> AST.Node {
    try parser.consume(.colon)

    let position = parser.lexer.filePosition
    let identifier: ByteString
    switch lvalue.kind {
    case .identifier(let id), .operator(let id):
      identifier = id

    default:
      throw parser.error(.badlvalue, message: "The lvalue for a compile time operation must be either an identifier or operator")
    }


    guard let token = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration, message: "Expected a type for this declaration") }
    switch token {
    // procedure type's
    case .lparen:
      let type = try parser.parseType()

      if case .tuple(_) = type { throw parser.error(.syntaxError) }
      // next should be a new scope '{' or a foreign body
      guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
      if case .lbrace = token { unimplemented("procedure bodies not yet ready") }
      else if case .directive(.foreignLLVM) = token {
        try parser.consume()
        guard case .string(let foreignName)? = try parser.lexer.peek() else {
          throw parser.error(.invalidDeclaration, message: "Expected foreign symbol name")
        }
        try parser.consume()

        let symbol = Symbol(identifier, filePosition: position, flags: .compileTime)
        symbol.type = type
        symbol.source = .llvm(foreignName)
        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol))
      }
    case .keyword(.struct):
      try parser.consume(.keyword(.struct))
      guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
      if case .lbrace = token { unimplemented("Custom struct's are not ready") }
      else if case .directive(.foreignLLVM) = token {
        try parser.consume()
        guard case .string(let foreignName)? = try parser.lexer.peek() else {
          throw parser.error(.invalidDeclaration, message: "Expected foreign symbol name")
        }
        try parser.consume()

        let symbol = Symbol(identifier, filePosition: position, flags: .compileTime)
        symbol.type = .type
        symbol.source = .llvm(foreignName)
        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol))
      }
      else { throw parser.error(.syntaxError, message: "Expected struct Body") }


    case .keyword(.enum):
      unimplemented("enum's not yet supported'")


    default:
      throw parser.error(.syntaxError)
    }

    fatalError("TODO: What happened here")
  }
}
