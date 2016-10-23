
struct Operator {

  enum Associativity { case none, left, right }

  let symbol: ByteString
  let lbp: UInt8
  let associativity: Associativity

  var nud: ((inout Parser) throws -> AST.Node)?
  var led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)?


  init(_ symbol: ByteString, lbp: UInt8, associativity: Associativity = .left,
       nud: ((inout Parser) throws -> AST.Node)?,
       led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)?) {

    self.symbol = symbol
    self.lbp = lbp
    self.associativity = associativity

    self.nud = nud
    self.led = led
  }
}

extension Operator {

  static var table: [Operator] = []

  static func lookup(_ symbol: ByteString) -> Operator? {
    return table.first(where: { $0.symbol == symbol })
  }

  static func infix(_ symbol: ByteString, bindingPower lbp: UInt8, associativity: Associativity = .left,
                    led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)? = nil) throws
  {

    guard symbol != "=" else { throw Error.invalidSymbol }

    let led = led ?? { parser, left in
      let (_, location) = try parser.consume()
      let node = AST.Node(.operator(symbol), location: location)
      let bp = (associativity == .left) ? lbp : lbp - 1
      let rhs = try parser.expression(bp)

      if case .none = associativity,
         case .operator(let symbol) = rhs.kind,
         case .none? = Operator.lookup(symbol)?.associativity {
        throw parser.error(.ambigiousOperatorUse)
      }

      node.add(children: [left, rhs])

      return node
    }

    if let index = table.index(where: { $0.symbol == symbol }) {
      guard table[index].led == nil else { throw Error.redefinition(symbol) }

      table[index].led = led
    } else {

      let op = Operator(symbol, lbp: lbp, associativity: associativity, nud: nil, led: led)
      table.append(op)
    }
  }

  static func prefix(_ symbol: ByteString, nud: ((inout Parser) throws -> AST.Node)? = nil) throws {

    guard symbol != "=" else { throw Error.invalidSymbol }

    let nud = nud ?? { parser in
      let (_, location) = try parser.consume()
      let operand = try parser.expression(70)
      return AST.Node(.operator(symbol), children: [operand], location: location)
    }

    if let index = table.index(where: { $0.symbol == symbol }) {
      guard table[index].nud == nil else { throw Error.redefinition(symbol) }

      table[index].nud = nud
    } else {

      let op = Operator(symbol, lbp: 70, associativity: .right, nud: nud, led: nil)
      table.append(op)
    }
  }

  static func assignment(_ symbol: ByteString) throws {

    guard symbol != "=" else { throw Error.invalidSymbol }

    try infix(symbol, bindingPower: 10, associativity: .right) { parser, lvalue in
      let (_, location) = try parser.consume()

      let node = AST.Node(.assignment(symbol), location: location)

      let rvalue = try parser.expression(9)
      node.add(children: [lvalue, rvalue])

      return node
    }
  }
}

extension Operator {

  // TODO(vdka): These need to become CompilerError's @ some point
  enum Error: Swift.Error {
    case invalidSymbol
    case redefinition(ByteString)
  }
}
