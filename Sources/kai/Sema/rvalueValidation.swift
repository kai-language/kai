
private extension AST {

  var rvalue: AST.Node {
    get { return children[1] }
    set { children[1] = newValue }
  }
}

extension AST {

  var isValidRvalue: Bool {

    switch kind {
    case .multiple:
      for child in children {
        if !child.isValidRvalue { return false }
      }
      return true

    case .dispose:
      return false

    default:
      return true
    }
  }
}

enum RvalueValidator: ASTValidator {

  static func error(_ message: String?, at node: AST.Node) -> SemanticError {
    return error(.badrvalue, message: message, at: node)
  }

  static var totalTime: Double = 0

  static func validate(_ node: AST.Node) throws {

    switch node.kind {
    case .declaration(_):
      guard !node.children.isEmpty else { return }
      if case .multiple? = node.children.first?.kind {
         throw error("number of rvalues does not match number of lvalues", at: node)
      } else {
        let rvalue = node.children[0]
        guard rvalue.isValidRvalue else { throw error("rvalue is invalid", at: rvalue) }
      }

    case .multipleDeclaration, .assignment(_):
      assert(node.children.count == 2)
      let rvalue = node.children[1]

      guard rvalue.isValidRvalue else { throw error("rvalue is invalid", at: rvalue) }

    default:
      break
    }
  }
}
