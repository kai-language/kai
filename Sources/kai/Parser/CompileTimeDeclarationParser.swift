
extension Parser {

    static func parseCompileTimeDeclaration(_ parser: inout Parser, _ lvalue: AST.Node) throws -> AST.Node {

        try parser.consume(.colon)
        try parser.consume(.colon)

        guard let token = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration) }
        switch token.kind {
        case .lparen: // procedure type parsing
            let type = try parser.parseType()

            // next should be a new scope '{' or a foreign body
            guard let (token, location) = try parser.lexer.peek() else { throw parser.error(.syntaxError) }

            switch token {
            case .lbrace:

                let bodyExpr = try parser.expression()

                let procBody = ProcBody.native(bodyExpr)

                let proc = AST.Node(.procLiteral(type: type, body: procBody))
                lvalue.add(proc)
                return lvalue

            case .directive(.foreign):
                try parser.consume()

                guard case .string(let foreignName)? = try parser.lexer.peek()?.kind else {
                    reportError("Expected foreign name", at: location)

                    return AST.Node(.invalid)
                }

                try parser.consume()

                let procBody = ProcBody.foreign(library: AST.Node(.invalid), name: foreignName.string, linkName: "")

                return AST.Node(.procLiteral(type: type, body: procBody))

            default:
                reportError("Expected procedure body or foreign directive", at: location)
            }

        case .keyword(.type):
            unimplemented("type declaration")

        case .keyword(.alias):
            unimplemented("aliasing")

        case .keyword(.struct):
            unimplemented("structures")

        case .keyword(.enum):
            unimplemented("enum's not yet supported'")

        case .identifier("infix"), .identifier("prefix"), .identifier("postfix"):
            throw parser.error(.syntaxError)

        default:
            throw parser.error(.syntaxError)
        }

        fatalError("TODO: What happened here")
    }
}
