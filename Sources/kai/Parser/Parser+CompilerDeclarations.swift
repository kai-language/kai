

/// Handles parsing for `::`
enum CompileTimeParser {

  /// Parser is just used if we need to throw an error.
  static func parseCompilerDeclaration(_ parser: inout Parser, _ lvalue: AST.Node) throws -> AST.Node {
    switch lvalue.kind {
    case .identifier(let id):
      return try parseCompileTimeExpression(id: id, parser: &parser, lvalue: lvalue)

    case .operator(let symbol):
      return try parseOperatorDeclaration(symbol: symbol, parser: &parser, lvalue: lvalue)

    default:
      throw parser.error(.badlvalue, message: "Compile time declarations can only be of certain types!") // TODO(vdka): What types?
    }
  }

  fileprivate static func parseCompileTimeExpression(id: ByteString, parser: inout Parser, lvalue: AST.Node) throws -> AST.Node {

    let position = parser.lexer.filePosition

    let rhs = try parser.expression(10) // NOTE: declarations have a low precedence

    let symbol = Symbol(id, kind: .variable, filePosition: position, flags: .compileTime)

    try SymbolTable.current.insert(symbol)

    return AST.Node(.declaration(symbol), children: [lvalue, rhs])
  }

  fileprivate static func parseOperatorDeclaration(symbol: ByteString, parser: inout Parser, lvalue: AST.Node) throws -> AST.Node {

    unimplemented()
  }
}
