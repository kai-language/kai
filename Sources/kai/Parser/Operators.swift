
struct Operator {

    enum Associativity { case none, left, right }

    let symbol: String
    let lbp: UInt8
    let associativity: Associativity

    var nud: ((inout Parser) throws -> AstNode)?
    var led: ((inout Parser, _ lvalue: AstNode) throws -> AstNode)?


    init(_ symbol: String, lbp: UInt8, associativity: Associativity = .left,
             nud: ((inout Parser) throws -> AstNode)?,
             led: ((inout Parser, _ lvalue: AstNode) throws -> AstNode)?) {

        self.symbol = symbol
        self.lbp = lbp
        self.associativity = associativity

        self.nud = nud
        self.led = led
    }
}

extension Operator {

    static var table: [Operator] = []

    static func lookup(_ symbol: String) -> Operator? {
        return table.first(where: { $0.symbol == symbol })
    }

    static func infix(_ symbol: String, bindingPower lbp: UInt8, associativity: Associativity = .left,
                                        led: ((inout Parser, _ lvalue: AstNode) throws -> AstNode)? = nil) throws
    {

        guard symbol != "=" else { throw Error.invalidSymbol }


        let led = led ?? { parser, left in
            let (_, location) = try parser.consume()
            let bp = (associativity == .left) ? lbp : lbp - 1

            let rhs = try parser.expression(bp)
            if  case .none = associativity,
                case .expr(.binary(let sym, lhs: _, rhs: _, _)) = rhs,
                case .none? = Operator.lookup(sym)?.associativity {

                throw parser.error(.ambigiousOperatorUse)
            }

            return AstNode.expr(.binary(op: symbol, lhs: left, rhs: rhs, location))
        }

        if let index = table.index(where: { $0.symbol == symbol }) {
            guard table[index].led == nil else { throw Error.redefinition(symbol) }

            table[index].led = led
        } else {

            let op = Operator(symbol, lbp: lbp, associativity: associativity, nud: nil, led: led)
            table.append(op)
        }
    }

    static func prefix(_ symbol: String, nud: ((inout Parser) throws -> AstNode)? = nil) throws {

        guard symbol != "=" else { throw Error.invalidSymbol }

        let nud = nud ?? { parser in
            let (_, location) = try parser.consume()
            let expr = try parser.expression(70)
            return AstNode.expr(.unary(op: symbol, expr: expr, location))
        }

        if let index = table.index(where: { $0.symbol == symbol }) {
            guard table[index].nud == nil else { throw Error.redefinition(symbol) }

            table[index].nud = nud
        } else {

            let op = Operator(symbol, lbp: 70, associativity: .right, nud: nud, led: nil)
            table.append(op)
        }
    }

    static func assignment(_ symbol: String) throws {

        guard symbol != "=" else { throw Error.invalidSymbol }

        try infix(symbol, bindingPower: 10, associativity: .right) { parser, lvalue in
            let (_, location) = try parser.consume()

            let rvalue = try parser.expression(9)

            // TODO(vdka): allow parsing multiple assignment.
            return AstNode.stmt(.assign(op: symbol, lhs: [lvalue], rhs: [rvalue], location))
        }
    }
}

extension Operator {

    // TODO(vdka): These need to become CompilerError's @ some point
    enum Error: Swift.Error {
        case invalidSymbol
        case redefinition(String)
    }
}
