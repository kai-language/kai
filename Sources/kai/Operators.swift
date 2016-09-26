
struct Operator {

  enum Associativity { case left, right }

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

  static func infix(_ symbol: ByteString, bindingPower lbp: UInt8, associativity: Associativity = .left,
                    led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)? = nil) throws
  {

    let led = led ?? { parser, left in
      let node = AST.Node(.operator(symbol))
      let bp = (associativity == .left) ? lbp : lbp - 1
      let rhs = try parser.expression(bp)
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

    let nud = nud ?? { parser in
      let operand = try parser.expression(70)
      return AST.Node(.operator(symbol), children: [operand])
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

    try infix(symbol, bindingPower: 10, associativity: .right) { parser, lvalue in

      let node = AST.Node(.assignment(symbol))
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`
      //   This can probably be done by handling `,` as a _special_ operator similar to languages like C
      guard case .identifier(let id) = lvalue.kind else { throw Error.badlvalue }
      guard SymbolTable.current.lookup(id) != nil else {
        throw parser.error(.badlvalue, message: "'\(id)' was not declared in this scope")
      }

      let rvalue = try parser.expression(9)
      node.add(children: [lvalue, rvalue])

      return node
    }
  }
}

extension Operator {

  enum Error: Swift.Error {
    case badlvalue
    case redefinition(ByteString)
  }
}

extension Lexer.Token {

  var lbp: UInt8? {
    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.lbp

    case .keyword(.declaration), .keyword(.compilerDeclaration):
      return 10

    default:
      return 0
    }
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

    case .lparen:
      return { parser in
        let expr = try parser.expression()
        try parser.consume(.rparen)
        return expr
      }

    case .keyword(.if):
      return { parser in

        let conditionExpression = try parser.expression()
        let thenExpression = try parser.expression()

        guard case .keyword(.else)? = try parser.lexer.peek() else {
          return AST.Node(.conditional, children: [conditionExpression, thenExpression])
        }

        try parser.consume(.keyword(.else))
        let elseExpression = try parser.expression()
        return AST.Node(.conditional, children: [conditionExpression, thenExpression, elseExpression])
      }

    case .lbracket:
      return { parser in

        // TODO(vdka): Traverse the AST upward, looking for parent scopes. if there are none, our parent is the global scope.

        let scopeSymbols = SymbolTable.push()

        let node = AST.Node(.scope(scopeSymbols))
        while let next = try parser.lexer.peek(), next != .rbracket {
          let expr = try parser.expression()
          node.add(expr)
        }
        try parser.consume(.rbracket)

        return node
      }

    default:
      return nil
    }
  }

  var led: ((inout Parser, _ left: AST.Node) throws -> AST.Node)? {

    switch self {
    case .operator(let symbol):
      return Operator.table.first(where: { $0.symbol == symbol })?.led

    // NOTE(vdka): Everything below here can be considered a language construct

    case .keyword(.declaration):
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`
      return { parser, lvalue in
        guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }

        let position = parser.lexer.filePosition
        let rhs = try parser.expression(self.lbp!)

        let symbol = Symbol(id, kind: .variable, filePosition: position)

        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol), children: [lvalue, rhs])
      }

    case .keyword(.compilerDeclaration):
      // TODO(vdka): This needs more logic to handle multiple assignment ala go `a, b = b, a`
      return { parser, lvalue in
        guard case .identifier(let id) = lvalue.kind else { throw parser.error(.badlvalue) }

        let position = parser.lexer.filePosition

        let rhs = try parser.expression(self.lbp!)

        let symbol = Symbol(id, kind: .variable, filePosition: position, flags: .compileTime)

        try SymbolTable.current.insert(symbol)

        return AST.Node(.declaration(symbol), children: [lvalue, rhs])
      }

    default:
      return nil
    }
  }
}
