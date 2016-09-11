
struct TypeResolver {

  static func resolve(for node: AST.Node) {

    switch node.kind {
    case .declarationReference:
      debug("Resolving type for \(node)")
      print(node.value)

    case .procedure:
      unimplemented()

    case .tuple:
      unimplemented()

    case .scope:
      break

    // case .staticDeclaration:
      // node.type = TypeResolver.resolve(for: node.children)

    default:
      debug("Not yet sure how to Resolve type for \(node)")
      break
    }
  }
}
