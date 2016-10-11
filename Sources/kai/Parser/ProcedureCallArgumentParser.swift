
extension Parser {

  /*
   '(' arg: expr, arg
  */
  static func parseProcedureCall(parser: inout Parser, lvalue: AST.Node) throws -> AST.Node {

    let (_, startLocation) = try parser.consume(.lparen)

    let callNode = AST.Node(.procedureCall, children: [lvalue], location: startLocation)

    var seenComma = false
    var seenLabel = false

    while let token = try parser.lexer.peek(), token.kind != .rparen {

      if case (.comma, let location) = token {

        guard !seenComma else { throw parser.error(.syntaxError, message: "Unexpected comma", location: location) }

        seenComma = true
        seenLabel = false

        try parser.consume(.comma)
      } else if case .identifier(let label) = token.kind,
        case .colon? = try parser.lexer.peek(aheadBy: 1)?.kind {

        if callNode.children.count > 2, !seenComma { throw parser.error(.expected(.comma), message: "Expected comma") }

        seenComma = false
        seenLabel = true

        try parser.consume() // ident
        try parser.consume(.colon)

        let labelNode = AST.Node(.argumentLabel(label), location: token.location)
        callNode.add(labelNode)
      } else {

        if callNode.children.count > 2, !seenComma && !seenLabel { throw parser.error(.expected(.comma), message: "Expected comma") }

        seenComma = false
        seenLabel = false

        let exprNode = try parser.expression(disallowMultiples: true)
        callNode.add(exprNode)
      }
    }

    try parser.consume(.rparen)

    return callNode
  }
}
