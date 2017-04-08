
struct PrefixOperator {

    let symbol: Operator

    let nud: ((inout Parser) throws -> AstNode)


    init(_ symbol: Operator,
         nud: @escaping ((inout Parser) throws -> AstNode)) {

        self.symbol = symbol

        self.nud = nud
    }
}

extension PrefixOperator {

    static var table: [PrefixOperator] = []

    static func lookup(_ symbol: Operator) -> PrefixOperator? {
        return table.first(where: { $0.symbol == symbol })
    }

    static func register(_ symbol: String, nud: ((inout Parser) throws -> AstNode)? = nil) {
        let symbol = Operator(rawValue: symbol)!

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

    let symbol: Operator
    let lbp: UInt8
    let associativity: Associativity

    let led: ((inout Parser, AstNode) throws -> AstNode)

    enum Associativity { case left, right }


    init(_ symbol: Operator, lbp: UInt8, associativity: Associativity = .left,
         led: @escaping ((inout Parser, _ left: AstNode) throws -> AstNode)) {

        self.symbol = symbol
        self.lbp = lbp
        self.associativity = associativity

        self.led = led
    }
}

extension InfixOperator {

    static var table: [InfixOperator] = []

    static func lookup(_ symbol: Operator) -> InfixOperator? {
        return table.first(where: { $0.symbol == symbol })
    }

    static func register(_ symbol: String,
                         bindingPower lbp: UInt8, associativity: Associativity = .left,
                         led: ((inout Parser, _ left: AstNode) throws -> AstNode)? = nil)
    {
        let symbol = Operator(rawValue: symbol)!

        let led = led ?? { parser, lhs in
            try parser.consume()
            let bp = (associativity == .left) ? lbp : lbp - 1

            let rhs = try parser.expression(bp)

            return AstNode.exprBinary(symbol, lhs: lhs, rhs: rhs, lhs.startLocation ..< rhs.endLocation)
        }

        let op = InfixOperator(symbol, lbp: lbp, associativity: associativity, led: led)
        table.append(op)
    }
}

