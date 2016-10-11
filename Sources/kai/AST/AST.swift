
class AST {

  typealias Node = AST

  weak var parent: Node?
  var children: [Node]

  var location: SourceLocation?
  var sourceRange: Range<SourceLocation>? {
    didSet {
      location = sourceRange?.lowerBound
    }
  }

  var kind: Kind

  /// - Note: If you create a node without a filePosition it defaults to that if it's first child, should if have children
  init(_ kind: Kind, parent: Node? = nil, children: [Node] = [], location: SourceLocation? = nil) {
    self.kind = kind
    self.parent = parent
    self.children = children
    self.location = location ?? children.first?.location

    for child in children {

      child.parent = self
    }
  }
}

extension AST {

  enum Kind {
    case empty
    case unknown

    case emptyFile(name: String)
    case file(name: String)
    case identifier(ByteString)

    /// this signifies a comma seperates set of values. `x, y = y, x` would parse into
    ///         =
    ///      m    m
    ///     x y  y x
    case multiple

    case type(KaiType)

    case procedure(Symbol)

    case scope(SymbolTable)

    case infixOperator(ByteString)
    case prefixOperator(ByteString)
    case postfixOperator(ByteString)

    case declaration(Symbol)
    case assignment(ByteString)

    case multipleDeclaration

    case conditional

    /// number of child nodes determine the 'arity' of the operator
    case `operator`(ByteString)

    /// This is the symbol of a operatorDeclaration that provides no information
    case operatorDeclaration

    case boolean(Bool)
    case real(ByteString)
    case string(ByteString)
    case integer(ByteString)
  }
}

extension AST {

  var isStandalone: Bool {
    switch self.kind {
    case .operatorDeclaration, .declaration(_): return true
    default: return false
    }
  }
}

extension AST.Node.Kind: Equatable {

  static func == (lhs: AST.Node.Kind, rhs: AST.Node.Kind) -> Bool {
    switch (lhs, rhs) {
    case
      (.operator(let l), .operator(let r)),
      (.identifier(let l), .identifier(let r)),
      (.infixOperator(let l), .infixOperator(let r)),
      (.prefixOperator(let l), .prefixOperator(let r)),
      (.postfixOperator(let l), .postfixOperator(let r)):

      return l == r

    default:
      return isMemoryEquivalent(lhs, rhs)
    }
  }
}
