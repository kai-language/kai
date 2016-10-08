
class AST {

  typealias Node = AST

  weak var parent: Node?
  var children: [Node]

  var filePosition: FileScanner.Position?

  var kind: Kind

  /// - Note: If you create a node without a filePosition it defaults to that if it's first child, should if have children
  init(_ kind: Kind, parent: Node? = nil, children: [Node] = [], filePosition: FileScanner.Position? = nil) {
    self.kind = kind
    self.parent = parent
    self.children = children
    self.filePosition = filePosition ?? children.first?.filePosition

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

    case multipleDeclaration([Symbol])
    case multipleAssignment([ByteString])

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

extension AST.Node.Kind: Equatable {

  static func == (lhs: AST.Node.Kind, rhs: AST.Node.Kind) -> Bool {
    switch (lhs, rhs) {
    case (.empty, .empty): return true
    case (.unknown, .unknown): return true
    default: return isMemoryEquivalent(lhs, rhs)
    }
  }
}
