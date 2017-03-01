
extension Parser {

    mutating func parseCompileTimeDeclaration(_ lvalue: AstNode) throws -> AstNode {

        try consume(.colon)
        try consume(.colon)

        guard let (token, startLocation) = try lexer.peek() else { throw error(.invalidDeclaration) }
        switch token {
        case .lparen: // procedure type parsing
            let type = try parseType()

            // next should be a new scope '{' or a foreign body
            guard let (token, location) = try lexer.peek() else { throw error(.syntaxError) }

            switch token {
            case .lbrace:

                let bodyExpr = try expression()

                let lit = AstNode.literal(.proc(.native(body: bodyExpr), type: type, startLocation))
                return AstNode.decl(.value(isVar: false, names: [lvalue], type: nil, values: [lit], lvalue.startLocation))

            case .directive(.foreign):
                try consume(.directive(.foreign))

                guard case (.ident(let libName), let libLocation)? = try lexer.peek() else {
                    reportError("Expected lib name", at: lexer.lastLocation)
                    return AstNode.invalid(startLocation)
                }

                try consume() // .ident(_)

                var symbolNameNode: AstNode?
                if case (.string(let name), let location)? = try lexer.peek() {
                    symbolNameNode = AstNode.ident(name, location)

                    try consume() // .string(_)

                } else {
                    guard case .ident(_) = lvalue else {
                        reportError("When omitting a symbol name the lvalue must be an identifier", at: lvalue)
                        return AstNode.invalid(lvalue.location.lowerBound)
                    }
                }

                /*
                 open      :: (path: ^u8, mode: int, perm: u32) -> Handle #foreign libc
                 unix_open :: (path: ^u8, mode: int, perm: u32) -> Handle #foreign libc "open"
                */

                let libNameNode = AstNode.ident(libName, libLocation)

                let lit = AstNode.literal(.proc(.foreign(lib: libNameNode, symbol: symbolNameNode ?? lvalue), type: type, type.startLocation))
                return AstNode.decl(.value(isVar: false, names: [lvalue], type: nil, values: [lit], lvalue.startLocation))

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

        default:
            throw error(.syntaxError)
        }

        fatalError("TODO: What happened here")
    }
}
