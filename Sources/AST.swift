
struct KaiType {

  var name: ByteString
  var members: [(name: ByteString, KaiType)]
}

struct AST {

  // TODO(vdka): The program AST's root Node should be the main function.
  var root: Node = Node(.file, name: "_")

  class Node {

    // TODO(vdka): add a file name and position field for Nodes.

    var kind: Kind
    var name: ByteString?
    var value: ByteString?
    var type: KaiType?

    var children: [Node] = []

    init(_ kind: Kind, name: ByteString? = nil, value: ByteString? = nil, type: KaiType? = nil, children: [AST.Node] = []) {
      self.kind = kind
      self.name = name
      self.value = value
      self.type = type
      self.children = children
    }

    enum Kind {
      case file
      case fileImport
      case unknown
      case type
      case typeList
      case procedure
      case parameterList
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

    let indentation = (0...depth).reduce("\n", { $0.0 + " " })

    description += indentation + "(" + String(describing: kind)

    if let name = name {
      description += " "
      description += "name: '\(String(name))'"
    }

    if let value = value {
      description += " "
      description += "value: '\(String(value))'"
    }

    // if let type = type {
    //   description += " "
    //   description += "type: '\(String(type))'"
    // }

    let childDescriptions = self.children
//      .sorted { $0.1.value < $1.1.value }
      .map { $0.pretty(depth: depth + 1) }
      .reduce("", { $0 + $1})

    // let pretty = "- \(key)\(payload)" + "\n" + "\(children)"

    // if !childDescriptions.isEmpty {
    //   for childDescription in childDescriptions {
    //     description += "\n"
    //     description += indentation
    //     description += childDescription
    //   }
    //
    //   description += "\n"
    //   description += indentation
    // }

    description += childDescriptions

    description += ")"


    return description
  }
}
