
struct IRBuilder {

  static func getIR(for node: AST.Node) -> ByteString {

    switch node.kind {
    case .procedure:

      return "define @" + "\(node.name!)" + "()"
      /// TODO(vdka): Scoping stuff

    default:
      return ""
    }
  }
}
