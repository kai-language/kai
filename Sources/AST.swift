
struct KaiType {

  var name: ByteString
  var members: [(name: ByteString, KaiType)]
}

struct AST {

  // TODO(vdka): The program AST's root Node should be the main function.
  var root: Node = Node(.unknown, name: "_")

  class Node {

    // TODO(vdka): add a file name and position field for Nodes.

    var kind: Kind
    var name: ByteString?
    var type: KaiType?

    var children: [Node] = []

    init(_ kind: Kind, name: ByteString? = nil, type: KaiType? = nil) {
      self.kind = kind
      self.name = name
      self.type = type
    }

    enum Kind {
      // case file
      case unknown
      case type
      case typeList
      case procedure
      case procedureReturn
    }
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

    return simpleTypeTable[children[1].name!] ?? children[1].name!
  }
}
