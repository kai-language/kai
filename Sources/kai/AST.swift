
class AST {

  typealias Node = AST

  weak var parent: Node?
  var children: [Node]

  var filePosition: FileScanner.Position?

  var kind: Kind

  init(_ kind: Kind, parent: Node? = nil, children: [Node] = [], filePosition: FileScanner.Position? = nil) {
    self.kind = kind
    self.parent = parent
    self.children = children
    self.filePosition = filePosition
    for child in children {

      child.parent = self
    }
  }
}

extension AST {

  enum Kind {
    case empty
    case unknown

    case emptyFile(name: ByteString)
    case file(name: ByteString)
    case declaration(Declaration)
    case identifier(ByteString)

    /// number of child nodes determine the 'arity' of the operator
    case `operator`(ByteString)

    case real(ByteString)
    case string(ByteString)
    case integer(ByteString)
  }
}
