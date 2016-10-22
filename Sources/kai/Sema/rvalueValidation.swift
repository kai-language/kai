
private extension AST {

  var rvalue: AST.Node {
    get { return children[1] }
    set { children[1] = newValue }
  }
}

enum RvalueValidator: ASTValidator {

  static var totalTime: Double = 0

  static func validate(_ node: AST.Node) throws {

    guard node.children.count > 1 else { return }

    switch node.kind {
    case .multipleDeclaration:
      for child in node.rvalue.children {
        if case .dispose = child.kind {
          throw SemanticError(.badrvalue, message: "'_' is not a valid rvalue", location: child.location!)
        }
      }

    case .assignment(_):
      if case .multiple = node.rvalue.kind {
        for child in node.rvalue.children {
          if case .dispose = child.kind {
            throw SemanticError(.badrvalue, message: "'_' is not a valid rvalue", location: child.location!)
          }
        }
      } else if case .dispose = node.rvalue.kind {
        throw SemanticError(.badrvalue, message: "'_' is not a valid rvalue", location: node.rvalue.location!)
      }

    case .declaration(_):
      if case .dispose = node.rvalue.kind {
        throw SemanticError(.badrvalue, message: "'_' is not a valid rvalue", location: node.rvalue.location!)
      }

    default:
    break
    }
  }
}
