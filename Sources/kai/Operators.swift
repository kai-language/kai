
struct Operator {

  enum Associativity { case left, right }

  let symbol: ByteString
  let bindingPower: Int16
  let associativity: Associativity

  var nud: ((inout Parser) throws -> AST.Node)?
  var led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)?


  init(_ symbol: ByteString, bindingPower: Int16, associativity: Associativity = .left,
       nud: ((inout Parser) throws -> AST.Node)?,
       led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)?) {

    self.symbol = symbol
    self.bindingPower = bindingPower
    self.associativity = associativity

    self.nud = nud
    self.led = led
  }
}

extension Operator {

  static var table: [Operator] = []

  static func infix(_ symbol: ByteString, bindingPower: Int16, associativity: Associativity = .left,
                    led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)? = nil) throws
  {

    let led = led ?? { parser, left in
      let node = AST.Node(.operator(symbol))
      let bp = (associativity == .left) ? bindingPower : bindingPower - 1
      let rhs = try parser.expression(bp)
      node.add(children: [left, rhs])

      return node
    }

    if let index = table.index(where: { $0.symbol == symbol }) {
      guard table[index].led == nil else { throw Error.redefinition(symbol) }

      table[index].led = led
    } else {

      let op = Operator(symbol, bindingPower: bindingPower, associativity: associativity, nud: nil, led: led)
      table.append(op)
    }
  }

  static func prefix(_ symbol: ByteString, nud: ((inout Parser) throws -> AST.Node)? = nil) throws {

    let nud = nud ?? { parser in
      let operand = try parser.expression(70)
      return AST.Node(.operator(symbol), children: [operand])
    }

    if let index = table.index(where: { $0.symbol == symbol }) {
      guard table[index].nud == nil else { throw Error.redefinition(symbol) }

      table[index].nud = nud
    } else {

      let op = Operator(symbol, bindingPower: 70, associativity: .right, nud: nud, led: nil)
      table.append(op)
    }
  }
}

extension Operator {

  enum Error: Swift.Error {
    case redefinition(ByteString)
  }
}

extension Lexer.Token {

  var bindingPower: Int16? {
    // TODO(vdka): Determine if we need to have more than just a default of -1 for non operators
    guard case .operator(let symbol) = self else { return -1 }
    return Operator.table.first(where: { $0.symbol == symbol })?.bindingPower
  }

  var nud: ((inout Parser) throws -> AST.Node)? {

    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.nud

    case .identifier(let symbol):
      return { _ in AST.Node(.identifier(symbol)) }

    case .integer(let literal):
      return { _ in AST.Node(.integer(literal)) }

    case .real(let literal):
      return { _ in AST.Node(.real(literal)) }

    case .string(let literal):
      return { _ in AST.Node(.string(literal)) }

    default:
      return nil
    }
  }

  var led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)? {

    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.led
      
    default:
      return nil
    }
  }
}
