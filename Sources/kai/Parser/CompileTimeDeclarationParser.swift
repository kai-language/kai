
extension Parser {

    static func parseCompileTimeDeclaration(_ parser: inout Parser, _ lvalue: AST.Node) throws -> AST.Node {

        try parser.consume(.colon)
        try parser.consume(.colon)

        let identifier: ByteString
        switch lvalue.kind {
        case .identifier(let id), .operator(let id):
            identifier = id

        default:
            throw parser.error(.badlvalue)
        }

        guard let token = try parser.lexer.peek() else { throw parser.error(.invalidDeclaration) }
        switch token.kind {
        // procedure type's
        case .lparen:
            let type = try parser.parseType()

            if case .tuple(_) = type { throw parser.error(.syntaxError) }
            // next should be a new scope '{' or a foreign body
            guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }

            if case .lbrace = token.kind {
                let symbol = Symbol(identifier, location: lvalue.location!, type: type, flags: .compileTime)

                let expr = try parser.expression()
                let procedure = AST.Node(.procedure(symbol), children: [expr], location: token.location)

                try SymbolTable.current.insert(symbol)

                return procedure
            } else if case .directive(.foreignLLVM) = token.kind {
                try parser.consume()
                guard case .string(let foreignName)? = try parser.lexer.peek()?.kind else {
                    throw parser.error(.invalidDeclaration)
                }
                try parser.consume()

                let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)
                symbol.type = type
                symbol.source = .llvm(foreignName)
                try SymbolTable.current.insert(symbol)

                return AST.Node(.declaration(symbol))
            } else if case .directive(.foreign) = token.kind {
                try parser.consume()
                guard case .string(let foreignName)? = try parser.lexer.peek()?.kind else {
                    throw parser.error(.invalidDeclaration)
                }
                try parser.consume()

                let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)
                symbol.type = type
                symbol.source = .extern(foreignName)
                try SymbolTable.current.insert(symbol)

                return AST.Node(.declaration(symbol))
            }

        case .keyword(.struct):
            try parser.consume(.keyword(.struct))
            guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
            if case .lbrace = token.kind { unimplemented("Custom struct's are not ready") }
            else if case .directive(.foreignLLVM) = token.kind {
                try parser.consume()
                guard case .string(let foreignName)? = try parser.lexer.peek()?.kind else {
                    throw parser.error(.invalidDeclaration)
                }
                try parser.consume()

                let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)
                symbol.type = .type
                symbol.source = .llvm(foreignName)
                try SymbolTable.current.insert(symbol)

                return AST.Node(.declaration(symbol))
            } else if case .directive(.foreign) = token.kind {
                try parser.consume()
                guard case .string(let foreignName)? = try parser.lexer.peek()?.kind else {
                    throw parser.error(.invalidDeclaration)
                }
                try parser.consume()

                let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)
                symbol.type = .type
                symbol.source = .extern(foreignName)
                try SymbolTable.current.insert(symbol)

                return AST.Node(.declaration(symbol))
            }
            else { throw parser.error(.syntaxError) }


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
