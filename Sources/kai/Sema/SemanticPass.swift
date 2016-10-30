
enum SemanticPass {

  static let validators: [ASTValidator.Type] = [RvalueValidator.self]

  static func run(_ node: AST.Node) throws {

    try performValidations(on: node)
    for child in node.children {
      try SemanticPass.run( child)
    }
  }

  static func performValidations(on node: AST.Node) throws {

    for validator in SemanticPass.validators {
      try validator.run(node, options: .timed)
    }
  }
}
