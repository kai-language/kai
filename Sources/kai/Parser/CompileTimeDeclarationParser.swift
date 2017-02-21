
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

                return AST.Node(.procedure(symbol))
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

                return AST.Node(.procedure(symbol))
            }

        case .keyword(.type):
            try parser.consume(.keyword(.type))
            guard let token = try parser.lexer.peek() else{ throw parser.error(.syntaxError) }
            if case .directive(.foreignLLVM) = token.kind {
                try parser.consume()
                guard case .string(let foreignName)? = try parser.lexer.peek()?.kind else {
                    throw parser.error(.invalidDeclaration)
                }
                try parser.consume()

                // TODO(vdka): parse the llvm type and create a type entry for it

                let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)

                // FIXME(vdka): This should not be invalid, maybe it should be like `opaque` or something
                symbol.type = .invalid
                symbol.source = .llvm(foreignName)
                try SymbolTable.current.insert(symbol)

                unimplemented()
                return AST.Node(.declaration(symbol))
            }

        case .keyword(.alias):
            try parser.consume(.keyword(.alias))
            guard let token = try parser.lexer.peek() else{ throw parser.error(.syntaxError) }
            guard case .identifier(let ident) = token.kind else {
                throw parser.error(.invalidDeclaration)
            }

            try parser.consume()

            guard let existingSymbol = SymbolTable.current.lookup(ident) else {
                throw parser.error(.invalidDeclaration)
            }

            guard case .record(let type)? = existingSymbol.type?.kind else {
                throw parser.error(.invalidDeclaration) // @BetterError
            }

            let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)

            let typeCopy = TypeRecord(name: type.name, kind: type.kind, source: type.source, node: type.node, llvm: type.llvm)
            symbol.type = typeCopy

            // NOTE(vdka): Do we want to copy their source?
            symbol.source = existingSymbol.source
            try SymbolTable.current.insert(symbol)

            return AST.Node(.declaration(symbol))

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

                let structInfo = TypeRecord.StructInfo(fieldCount: 0, fieldTypes: [])
                let type = TypeRecord(name: identifier.string, kind: .struct(structInfo), source: .llvm, node: nil, llvm: nil)

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

                let structInfo = TypeRecord.StructInfo(fieldCount: 0, fieldTypes: [])
                let type = TypeRecord(name: identifier.string, kind: .struct(structInfo), source: .extern(foreignName), node: nil, llvm: nil)

                let symbol = Symbol(identifier, location: lvalue.location!, flags: .compileTime)
                symbol.type = type
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
