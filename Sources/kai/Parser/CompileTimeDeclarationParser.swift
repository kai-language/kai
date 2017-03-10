
extension Parser {

    mutating func parseCompileTimeDeclaration(_ lvalue: AstNode) throws -> AstNode {

        try consume(.colon)
        try consume(.colon)

        guard let (token, startLocation) = try lexer.peek() else { throw error(.invalidDeclaration) }
        switch token {
        case .float(let val):
            try consume()
            let lit = AstNode.litFloat(val, startLocation ..< lexer.lastLocation)
            return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [lit], lvalue.startLocation ..< lit.endLocation)

        case .integer(let val):
            try consume()
            let lit = AstNode.litInteger(val, startLocation ..< lexer.lastLocation)
            return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [lit], lvalue.startLocation ..< lit.endLocation)

        case .string(let val):
            try consume()
            let lit = AstNode.litString(val, startLocation ..< lexer.lastLocation)
            return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [lit], lvalue.startLocation ..< lit.endLocation)

        case .lparen: // procedure type parsing
            let type = try parseType()

            // NOTE(vdka): Check if the lhs type is a proc type. If it is and the next token is '{' _then_ we have a litProc

            // next should be a new scope '{' or a foreign body
            guard let (token, location) = try lexer.peek() else { throw error(.syntaxError) }

            switch token {
            case .lbrace:

                let bodyExpr = try expression()

                let lit = AstNode.litProc(type: type, body: bodyExpr, startLocation ..< startLocation)
                return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [lit], startLocation ..< startLocation)

            case .directive(.foreign):
                try consume(.directive(.foreign))

                guard case (.ident(let libName), let libLocation)? = try lexer.peek() else {
                    reportError("Expected lib name", at: lexer.lastLocation)
                    return AstNode.invalid(lvalue.startLocation ..< lexer.lastLocation)
                }

                try consume() // .ident(_)

                var symbolNameNode: AstNode?
                if case (.string(let name), let location)? = try lexer.peek() {
                    symbolNameNode = AstNode.ident(name, location ..< lexer.lastLocation)

                    try consume() // .string(_)

                } else {
                    guard case .ident(_) = lvalue else {
                        reportError("When omitting a symbol name the lvalue must be an identifier", at: lvalue)
                        return AstNode.invalid(lvalue.location)
                    }
                }

                /*
                 open      :: (path: ^u8, mode: int, perm: u32) -> Handle #foreign libc
                 unix_open :: (path: ^u8, mode: int, perm: u32) -> Handle #foreign libc "open"
                */

                let libNameNode = AstNode.ident(libName, libLocation ..< lexer.lastLocation)

                let foreignNode = AstNode.directive("foreign", args: [libNameNode, symbolNameNode ?? lvalue], location ..< location)
                let lit = AstNode.litProc(type: type, body: foreignNode, type.startLocation ..< foreignNode.endLocation)
                return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [lit], lvalue.startLocation ..< lit.endLocation)

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
