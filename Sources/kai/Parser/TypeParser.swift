
extension Parser {

  mutating func parseType() throws -> KaiType {

    /**
     valid type's will be one of the following forms:
       - [x] id
       - [x] '(' type { ',' type } ')'
       - [x] '(' id ':' type { ',' id ':' type } ')' '->' type
    */

    if case .identifier(let id)? = try lexer.peek() { // id
      try consume()

      return .unknown(id)
    }

    try consume(.lparen)

    if case .colon? = try lexer.peek(aheadBy: 1) {
      // next valid things are a type or an argument, because an argument must be
      // followed by a ':' we can look ahead and see what follow's to determine
      // the next action
      // We are parsing the following case.
      // '(' id ':' type { ',' id ':' type } ')' '->' type

      var labels: [ByteString] = []
      var types: [KaiType] = []
      while let token = try lexer.peek() {
        guard case .identifier(let label) = token else { throw error(.syntaxError) }
        try consume()
        try consume(.colon)
        let type = try parseType()

        labels.append(label)
        types.append(type)

        if case .rparen? = try lexer.peek() {
          try consume()
          guard case .keyword(.returnType)? = try lexer.peek() else {
            throw error(.expected(.keyword(.returnType)), message: "Expected a return type")
          }
          try consume()
          let returnType = try parseType()

          return KaiType.procedure(labels: labels, arguments: types, returnType: returnType)
        }

        if case .keyword(.returnType)? = try lexer.peek() {
          // now we just need to parse the return type and construct the AST.Node

          let returnType = try parseType()

          return KaiType.procedure(labels: labels, arguments: types, returnType: returnType)
        }
      }
    } else {

      /**
       we are parsing for one of the following cases
         - '(' type { ',' type } ')'
         - '(' type { ',' type } ')' '->' type
      */

      var types: [KaiType] = []
      while true {
        let type = try parseType()

        types.append(type)

        guard let token = try lexer.peek() else { throw error(.syntaxError) }
        if case .comma = token { try consume(.comma) }
        else if case .rparen = token {
          try consume(.rparen)
          if case .keyword(.returnType)? = try lexer.peek() {
            try consume(.keyword(.returnType))
            let returnType = try parseType()
            return .procedure(labels: nil, arguments: types, returnType: returnType)
          } else { return .tuple(types) }
        }

        if case .keyword(.returnType)? = try lexer.peek() {
          // now we just need to parse the return type and construct the AST.Node

          let returnType = try parseType()

          return KaiType.procedure(labels: nil,
                                   arguments: types,
                                   returnType: returnType)
        }
      }
    }

    // TODO(vdka): I forget what is unimplemented here. That's awkward.
    unimplemented()
  }
}
