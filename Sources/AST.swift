
struct AST {

  // TODO(vdka): The program AST's root Node should be the main function.
  var root: Node = Node(.file, name: "_")

  class Node {

    // TODO(vdka): add a file name and position field for Nodes.

    weak var parent: Node?
    var kind: Kind
    var filePosition: FileScanner.Position?
    var name: ByteString?
    var value: ByteString?

    var children: [Node] = []

    init(_ kind: Kind,
           name: ByteString? = nil,
           filePosition: FileScanner.Position? = nil,
           value: ByteString? = nil,
           children: [AST.Node] = []) {

      self.kind = kind
      self.name = name
      self.filePosition = filePosition
      self.value = value
      self.children = children
    }

    enum Kind {
      case file
      case emptyFile

      case call

      case fileImport
      case unknown
      case type

      case identifier

      case declarationReference

      case typeList
      case procedure
      case parameterList
      case procedureArgumentList
      case procedureArgument
      case procedureReturn
      case scope
      case returnStatement
      case tuple
      case integer
      case real
      case string
      case staticDeclaration
    }
  }
}

extension AST.Node {

  func add(_ child: AST.Node) {
    child.parent = self
    children.append(child)
  }
}

// TODO(vdka): Completely replace
let simpleTypeTable: [ByteString: ByteString] = ["Int": "i64"]

extension AST.Node {

  var procedureArgumentTypeNames: [ByteString]? {

    guard case .procedure = kind else { return nil }

    return children[0].children.map { simpleTypeTable[$0.name!] ?? $0.name! }
  }

  var procedureReturnTypeName: ByteString? {

    guard case .procedure = kind else { return nil }

    return simpleTypeTable[children[1].children[0].name!] ?? children[1].children[0].name!
  }

  var procedureBody: AST.Node? {
    guard case .procedure = kind else { return nil }

    return children[2]
  }

  func pretty(depth: Int = 0) -> String {
    var description = ""

    let indentation = (0...depth).reduce("\n", { $0.0 + "  " })

    description += indentation + "(" + String(describing: kind)

    if let name = name {
      description += " "
      description += "name: '\(String(name))'"
    }

    if let value = value {
      description += " "
      description += "value: '\(String(value))'"
    }

    let childDescriptions = self.children
      .map { $0.pretty(depth: depth + 1) }
      .reduce("", { $0 + $1})

    description += childDescriptions

    description += ")"


    return description
  }
}

extension AST.Node {

  var description: String {
    return pretty()
  }
}
