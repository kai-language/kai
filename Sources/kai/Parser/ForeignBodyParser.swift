
extension Parser {

  mutating func parseForeignBody() throws -> Symbol.Source {

    try consume(.directive(.foreignLLVM)) // hard code it while we have 1 type of foreign

    guard case .string(let foreignName)? = try lexer.peek()?.kind else {
      throw error(.syntaxError, message: "Expected string literal for foreign symbol name")
    }
    try consume()

    return .llvm(foreignName)
  }
}
