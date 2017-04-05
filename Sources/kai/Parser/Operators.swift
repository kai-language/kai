
struct PrefixOperator {

    let symbol: String

    let nud: ((inout Parser) throws -> AstNode)


    init(_ symbol: String,
         nud: @escaping ((inout Parser) throws -> AstNode)) {

        self.symbol = symbol

        self.nud = nud
    }
}

extension PrefixOperator {

    static var table: [PrefixOperator] = []

    static func lookup(_ symbol: String) -> PrefixOperator? {
        return table.first(where: { $0.symbol == symbol })
    }

    static func register(_ symbol: String, nud: ((inout Parser) throws -> AstNode)? = nil) {

        let nud = nud ?? { parser in
            let (_, location) = try parser.consume()

            let prevState = parser.state
            defer { parser.state = prevState }
            parser.state.insert(.disallowComma)

            let expr = try parser.expression(70)
            return AstNode.exprUnary(symbol, expr: expr, location ..< expr.endLocation)
        }

        let op = PrefixOperator(symbol, nud: nud)
        table.append(op)
    }

}


struct InfixOperator {

    let symbol: String
    let lbp: UInt8
    let associativity: Associativity

    let led: ((inout Parser, AstNode) throws -> AstNode)

    enum Associativity { case left, right }


    init(_ symbol: String, lbp: UInt8, associativity: Associativity = .left,
         led: @escaping ((inout Parser, _ left: AstNode) throws -> AstNode)) {

        self.symbol = symbol
        self.lbp = lbp
        self.associativity = associativity

        self.led = led
    }
}

extension InfixOperator {

    static var table: [InfixOperator] = []

    static func lookup(_ symbol: String) -> InfixOperator? {
        return table.first(where: { $0.symbol == symbol })
    }

    static func register(_ symbol: String,
                         bindingPower lbp: UInt8, associativity: Associativity = .left,
                         led: ((inout Parser, _ left: AstNode) throws -> AstNode)? = nil)
    {

        let led = led ?? { parser, lhs in
            try parser.consume()
            let bp = (associativity == .left) ? lbp : lbp - 1

            let rhs = try parser.expression(bp)

            return AstNode.exprBinary(symbol, lhs: lhs, rhs: rhs, lhs.startLocation ..< rhs.endLocation)
        }

        let op = InfixOperator(symbol, lbp: lbp, associativity: associativity, led: led)
        table.append(op)
    }

    static func assignmentAssignment(_ symbol: String) throws {

        register(symbol, bindingPower: 10, associativity: .right) { parser, lvalue in
            try parser.consume()

            let rvalue = try parser.expression(9)

            // TODO(vdka): Potentially disallow multiple special assignment expressions.

            return AstNode.stmtAssign(symbol, lhs: [lvalue], rhs: [rvalue], lvalue.startLocation ..< rvalue.endLocation)
        }
    }
}

