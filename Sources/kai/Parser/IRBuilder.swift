import CLLVM
/*
struct IRBuilder {

  static func getIR(for node: AST.Node, indentationLevel: Int = 0) -> ByteString {

    let indentation = ByteString(Array(repeating: " ", count: indentationLevel))

    var output: ByteString = ""

    switch node.kind {
    case .file:
      output.append(contentsOf: "; " + ByteString(node.name!))
      return output

    case .procedure:
      // TODO(vdka): Is symbol global or local?

      output.append(contentsOf: "define")
      output.append(contentsOf: " " + node.procedureReturnTypeName! + " ")

      /// TODO(vdka): Think about Scoping '@' is global '%' is local
      output.append(contentsOf: "@" + node.name!)

      // TODO(vdka): Do this properly
      if node.procedureArgumentTypeNames!.isEmpty {
        output.append(contentsOf: "() ")
      } else {
        unimplemented("Multiple arguments")
      }

      let irForBody = IRBuilder.getIR(for: node.procedureBody!, indentationLevel: indentationLevel + 2)

      output.append(contentsOf: irForBody)

      return output

    case .scope:
      output.append("{")
      output.append("\n")

      for child in node.children {
        let ir = IRBuilder.getIR(for: child, indentationLevel: indentationLevel)
        output.append(contentsOf: ir)
      }

      output.append("\n")
      output.append("}")

      return output

    case .returnStatement:
      output.append(contentsOf: indentation)
      output.append(contentsOf: "ret ")

      return output

    case .integer:
      output.append(contentsOf: "i64 ")

      output.append(contentsOf: node.value!)

      return output

    default:
      return ""
    }
  }
}
*/
