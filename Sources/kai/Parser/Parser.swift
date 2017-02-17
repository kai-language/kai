

struct Parser {

    var lexer: Lexer
    var context: Context = Context()

    var errors: UInt = 0

    init(_ lexer: inout Lexer) {
        self.lexer = lexer
    }

    mutating func parse() throws -> (AST, errors: UInt) {

        let node = AST.Node(.file(name: lexer.scanner.file.name))

        while true {
            let expr: AST.Node
            do {
                expr = try expression()
            } catch let error as Parser.Error {
                try error.recover(with: &self)
                continue
            } catch { throw error }

            guard expr.kind != .empty else { return (node, errors) }

            node.children.append(expr)
        }
    }

    static func parse(_ lexer: inout Lexer) throws -> (AST, errors: UInt) {

        var parser = Parser(&lexer)

        return try parser.parse()
    }

    mutating func expression(_ rbp: UInt8 = 0) throws -> AST.Node {

        // TODO(vdka): This should probably throw instead of returning an empty node. What does an empty AST.Node even mean.
        guard let (token, location) = try lexer.peek() else { return AST.Node(.empty) }

        guard let nud = try nud(for: token) else { throw error(.expectedExpression) }

        var left = try nud(&self)
        left.location = location

        // operatorImplementation's need to be skipped too.
        if case .operatorDeclaration = left.kind { return left }
        else if case .declaration(_) = left.kind { return left }
        else if case .comma? = try lexer.peek()?.kind, case .procedureCall = context.state { return left }

        while let (nextToken, _) = try lexer.peek(), let lbp = lbp(for: nextToken),
            rbp < lbp
        {
            guard let led = try led(for: nextToken) else { throw error(.nonInfixOperator(nextToken)) }

            left = try led(&self, left)
        }

        return left
    }
}

extension Parser {

    mutating func lbp(for token: Lexer.Token) -> UInt8? {

        switch token {
        case .operator(let symbol):

            switch try? (lexer.peek(aheadBy: 1)?.kind, lexer.peek(aheadBy: 2)?.kind) {
            case (.colon?, .colon?)?:
                return 0

            default:
                return Operator.table.first(where: { $0.symbol == symbol })?.lbp
            }

        case .colon:
            return UInt8.max

        case .comma:
            return 180

        case .equals:
            return 160

        case .lbrack, .lparen, .dot:
            return 20

        default:
            return 0
        }
    }

    mutating func nud(for token: Lexer.Token) throws -> ((inout Parser) throws -> AST.Node)? {

        switch token {
        case .operator(let symbol):
            // If the next token is a colon then this should be a declaration
            switch try (lexer.peek(aheadBy: 1)?.kind, lexer.peek(aheadBy: 2)?.kind) {
            case (.colon?, .colon?):
                return Parser.parseOperatorDeclaration

            default:
                return Operator.table.first(where: { $0.symbol == symbol })?.nud
            }

        case .identifier(let symbol):
            try consume()
            return { parser in AST.Node(.identifier(symbol)) }

        case .underscore:
            try consume()
            return { _ in AST.Node(.dispose) }

        case .integer(let literal):
            try consume()
            return { _ in AST.Node(.integer(literal)) }

        case .real(let literal):
            try consume()
            return { _ in AST.Node(.real(literal)) }

        case .string(let literal):
            try consume()
            return { _ in AST.Node(.string(literal)) }

        case .keyword(.true):
            try consume()
            return { _ in AST.Node(.boolean(true)) }

        case .keyword(.false):
            try consume()
            return { _ in AST.Node(.boolean(false)) }

        case .lparen:
            return { parser in
                try parser.consume(.lparen)
                let expr = try parser.expression()
                try parser.consume(.rparen)
                return expr
            }

        case .keyword(.if):
            return { parser in
                let (_, startLocation) = try parser.consume(.keyword(.if))

                let conditionExpression = try parser.expression()
                let thenExpression = try parser.expression()

                guard case .keyword(.else)? = try parser.lexer.peek()?.kind else {
                    return AST.Node(.conditional, children: [conditionExpression, thenExpression], location: startLocation)
                }

                try parser.consume(.keyword(.else))
                let elseExpression = try parser.expression()
                return AST.Node(.conditional, children: [conditionExpression, thenExpression, elseExpression], location: startLocation)
            }

        case .lbrace:
            return { parser in
                let (_, startLocation) = try parser.consume(.lbrace)

                let scopeSymbols = SymbolTable.push()
                defer { SymbolTable.pop() }

                let node = AST.Node(.scope(scopeSymbols))
                while let next = try parser.lexer.peek()?.kind, next != .rbrace {
                    let expr = try parser.expression()
                    node.add(expr)
                }

                let (_, endLocation) = try parser.consume(.rbrace)

                node.sourceRange = startLocation..<endLocation

                return node
            }

        case .directive(.file):
            let (_, location) = try consume()
            let wrapped = ByteString(location.file)
            return { _ in AST.Node(.string(wrapped)) }

        case .directive(.line):
            let (_, location) = try consume()
            let wrapped = ByteString(location.line.description)
            return { _ in AST.Node(.integer(wrapped)) }

        case .directive(.import):
            return Parser.parseImportDirective

        default:
            return nil
        }
    }

    mutating func led(for token: Lexer.Token) throws -> ((inout Parser, AST.Node) throws -> AST.Node)? {

        switch token {
        case .operator(let symbol):
            return Operator.table.first(where: { $0.symbol == symbol })?.led

        case .dot:
            return { parser, lvalue in
                let (_, location) = try parser.consume(.dot)

                guard case let (.identifier(member), memberLocation)? = try parser.lexer.peek() else { throw parser.error(.expectedMemberName) }
                try parser.consume()

                let rvalue = AST.Node(.identifier(member), location: memberLocation)

                return AST.Node(.memberAccess, children: [lvalue, rvalue], location: location)
            }

        case .comma:
            return { parser, lvalue in
                try parser.consume()

                let rhs = try parser.expression(UInt8.max)

                if case .multiple = lvalue.kind { lvalue.children.append(rhs) }
                else { return AST.Node(.multiple, children: [lvalue, rhs]) }

                return lvalue
            }

        case .lbrack:
            return { parser, lvalue in
                let (_, startLocation) = try parser.consume(.lbrack)
                let expr = try parser.expression()
                try parser.consume(.rbrack)

                return AST.Node(.subscript, children: [lvalue, expr], location: startLocation)
            }

        case .lparen:

            return Parser.parseProcedureCall

        case .equals:

            return { parser, lvalue in
                let (_, location) = try parser.consume(.equals)

                let rhs = try parser.expression()

                return AST.Node(.assignment("="), children: [lvalue, rhs], location: location)
            }

        case .colon:

            if case .colon? = try lexer.peek(aheadBy: 1)?.kind { return Parser.parseCompileTimeDeclaration } // '::'
            return { parser, lvalue in
                // ':' 'id' '=' 'expr' | ':' '=' 'expr'

                try parser.consume(.colon)

                switch lvalue.kind {
                case .identifier(let id):
                    let symbol = Symbol(id, location: lvalue.location!)
                    try SymbolTable.current.insert(symbol)

                    switch try parser.lexer.peek()?.kind {
                    case .equals?: // type infered
                        try parser.consume()
                        let rhs = try parser.expression()
                        return AST.Node(.declaration(symbol), children: [rhs], location: lvalue.location)

                    default: // type provided
                        let type = try parser.parseType()
                        symbol.type = type

                        try parser.consume(.equals)
                        let rhs = try parser.expression()
                        return AST.Node(.declaration(symbol), children: [rhs])
                    }

                case .multiple:
                    let symbols: [Symbol] = try lvalue.children.map { node in
                        // NOTE(vdka): Unfortunately, and go falls into this trap also, if your _infered_ assignment operators
                        //  lvalue is predefined it must be redefined. This makes no sense for anything other than a identifier
                        // TODO(vdka): Need to really work out the finicky behaviour of the ':=' operator
                        guard case .identifier(let id) = node.kind else { throw parser.error(.badlvalue) }
                        let symbol = Symbol(id, location: node.location!)
                        try SymbolTable.current.insert(symbol)

                        return symbol
                    }

                    switch try parser.lexer.peek()?.kind {
                    case .equals?:
                        // We will need to infer the type. The AST returned will have 2 child nodes.
                        try parser.consume()
                        let rvalue = try parser.expression()
                        // TODO(vdka): Pull the rvalue's children onto the generated node assuming it is a multiple node.

                        let lvalue = AST.Node(.multiple, children: symbols.map({ AST.Node(.declaration($0), location: $0.location) }))

                        return AST.Node(.multipleDeclaration, children: [lvalue, rvalue], location: symbols.first?.location)

                    case .identifier?:
                        unimplemented("Explicit types in multiple declaration's is not yet implemented")

                    default:
                        throw parser.error(.syntaxError)
                    }

                case .operator(_):
                    unimplemented()

                default:
                    fatalError("bad lvalue?")
                }

                unimplemented()
            }

        default:
            return nil
        }
    }
}


// - MARK: Helpers

extension Parser {

    @discardableResult
    mutating func consume(_ expected: Lexer.Token? = nil) throws -> (kind: Lexer.Token, location: SourceLocation) {
        guard let expected = expected else {
            // Seems we exhausted the token stream
            // TODO(vdka): Fix this up with a nice error message
            guard try lexer.peek() != nil else { fatalError() }
            return try lexer.pop()
        }

        guard try lexer.peek()?.kind == expected else {
            throw error(.expected("something TODO ln Parser.swift:324"), location: try lexer.peek()!.location)
        }

        return try lexer.pop()
    }
}
