
extension Parser {

    static func parseOperatorDeclaration(parser: inout Parser) throws -> AST.Node {

        let operatorToken = try parser.consume()
        guard case .operator(let op) = operatorToken.kind else { preconditionFailure() }

        try parser.consume(.colon)
        try parser.consume(.colon)

        guard let token = try parser.lexer.peek() else { throw parser.error(.expectedOperator) }
        switch token.kind {
        case .lparen:
            let type = try parser.parseType()

            // We should now expect a body meaning we should have '{' | '#foreign' next
            guard let token = try parser.lexer.peek() else { throw parser.error(.syntaxError) }
            if case .lbrace = token.kind { unimplemented("Operator bodies not yet implemented") } // TODO(vdka): also check for labels
            else if case .directive(.foreignLLVM) = token.kind {

                let symbol = Symbol(op, location: operatorToken.location, flags: .compileTime)
                symbol.type = type
                symbol.source = try parser.parseForeignBody()
                try SymbolTable.current.insert(symbol)

                return AST.Node(.declaration(symbol))
            } else { throw parser.error(.expectedBody) }

        case .identifier(_):
            try parser.consume()
            try parser.consume(.identifier("operator"))
            switch token.kind {
            case .identifier("infix"):
                try parser.consume(.lbrace)

                var associativity = Operator.Associativity.none
                switch try parser.lexer.peek()?.kind {
                case .identifier("associativity")?:
                    try parser.consume()

                    switch try parser.lexer.peek()?.kind {
                    case .identifier("left")?:
                        associativity = .left

                    case .identifier("right")?:
                        associativity = .right

                    case .identifier("none")?:
                        associativity = .none

                    default:
                        throw parser.error(.unknownAssociativity)
                    }

                    try parser.consume()

                    // precedence is required.
                    fallthrough

                case .identifier("precedence")?:
                    try parser.consume(.identifier("precedence"))
                    guard case .integer(let value)? = try parser.lexer.peek()?.kind else { throw parser.error(.expectedPrecedence) }
                    try parser.consume()

                    guard let precedence = UInt8(value.description) else { throw parser.error(.expectedPrecedence) }
                    try parser.consume(.rbrace)

                    try Operator.infix(op, bindingPower: precedence, associativity: associativity)
                    return AST.Node(.operatorDeclaration)

                default:
                    throw parser.error(.expectedPrecedence)
                }

            case .identifier("prefix"):
                if case .lbrace? = try parser.lexer.peek()?.kind { throw parser.error(.unaryOperatorBodyForbidden) }
                try Operator.prefix(op)
                return AST.Node(.operatorDeclaration)

            case .identifier("postfix"):
                if case .lbrace? = try parser.lexer.peek()?.kind { throw parser.error(.unaryOperatorBodyForbidden) }
                try Operator.prefix(op)
                unimplemented()

            default:
                throw parser.error(.expectedOperator)
            }

        default:
            throw parser.error(.expectedOperator)
        }
    }
}
