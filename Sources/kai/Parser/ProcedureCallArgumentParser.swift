
extension Parser {

  /*
   '(' arg: expr, arg
  */
  static func parseProcedureCall(parser: inout Parser, lvalue: AST.Node) throws -> AST.Node {

    parser.push(context: .procedureCall)
    defer { parser.popContext() }

    let (_, startLocation) = try parser.consume(.lparen)

    let callNode = AST.Node(.procedureCall, children: [lvalue], location: startLocation)

    var wasComma = false
    var wasLabel = false

    while let token = try parser.lexer.peek(), token.kind != .rparen {

      if case .comma = token.kind {

        if wasComma || callNode.children.count <= 2 { try parser.error(.unexpectedComma).recover(with: &parser) }

        wasComma = true
        wasLabel = false

        try parser.consume(.comma)
      } else if case .identifier(let label) = token.kind,
        case .colon? = try parser.lexer.peek(aheadBy: 1)?.kind {
          // TODO(vdka): Look ahead here makes recovery more difficult. This is a good scenario for a state machine.

        if callNode.children.count > 2, !wasComma { try parser.error(.expectedComma).recover(with: &parser) }

        wasComma = false
        wasLabel = true

        try parser.consume() // ident
        try parser.consume(.colon)

        let labelNode = AST.Node(.argumentLabel(label), location: token.location)
        callNode.add(labelNode)
      } else {

        if callNode.children.count > 2, !wasComma && !wasLabel { try parser.error(.expectedComma).recover(with: &parser) }

        wasComma = false
        wasLabel = false

        let exprNode = try parser.expression()
        callNode.add(exprNode)
      }
    }

    if wasComma { try parser.error(.unexpectedComma).recover(with: &parser) }

    try parser.consume(.rparen)

    return callNode
  }
}
