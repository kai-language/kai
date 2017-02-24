
extension Parser {

    mutating func parseType() throws -> AST.Node {

        guard let (token, location) = try lexer.peek() else {
            reportError("Expected a type", at: lexer.lastLocation)
            return AST.Node(.invalid)
        }
        
        switch token {
        case .identifier(let ident):
            try consume()

            return AST.Node(.identifier(ident), location: location)

        case .lparen:
            try consume(.lparen)
            var wasComma = false

            var labels: [(callsite: ByteString?, binding: ByteString)]? = []
            if case (.identifier(_)?, .comma?) = try (lexer.peek()?.kind, lexer.peek(aheadBy: 1)?.kind) {
                labels = nil // we do not expect any labels.
            }

            // TODO(vdka): Report error not throw error.
            var types: [AST.Node] = []
            while let (token, location) = try lexer.peek(), token != .rparen {

                switch token {
                case .comma:

                    if types.isEmpty || wasComma { try error(.unexpectedComma).recover(with: &self) }

                    wasComma = true

                    try consume(.comma)

                case .underscore:
                    guard case .identifier(let binding)? = try lexer.peek(aheadBy: 1)?.kind else {
                        reportError("Invalid syntax", at: lexer.lastLocation)
                        return AST.Node(.invalid)
                    }
                    guard case .colon? = try lexer.peek(aheadBy: 2)?.kind else {
                        reportError("Invalid syntax", at: lexer.lastLocation)
                        return AST.Node(.invalid, location: location)
                    }

                    try consume(.underscore)
                    try consume() // .identifier(_)
                    try consume(.colon)

                    labels?.append((callsite: nil, binding: binding))

                    let type = try parseType()
                    types.append(type)

                case .identifier(let callsite):

                    switch try lexer.peek(aheadBy: 1)?.kind {
                    case .identifier(let binding)?: // `(label binding: Type)`
                        try consume() // .identifier(_)
                        try consume() // .identifier(_)
                        try consume(.colon)

                        // TODO(vdka): Better message
                        if types.isEmpty && wasComma { throw error(.unexpectedComma) }
                        else if !types.isEmpty && !wasComma { throw error(.expectedComma) }
                        if labels == nil { throw error(.syntaxError) }

                        wasComma = false

                        labels?.append((callsite: callsite, binding: binding))

                        let type = try parseType()
                        types.append(type)

                    case .colon?:
                        if types.isEmpty && wasComma { throw error(.unexpectedComma) }
                        else if !types.isEmpty && !wasComma { throw error(.expectedComma) }
                        if labels == nil { throw error(.syntaxError) } // TODO(vdka): Better message

                        wasComma = false

                        try consume() // .identifier(_)
                        try consume(.colon)

                        labels?.append((callsite: nil, binding: callsite))
                        
                        let type = try parseType()
                        types.append(type)

                    default:
                        if types.isEmpty && wasComma {
                            throw error(.unexpectedComma)
                        } else if !types.isEmpty && !wasComma {
                            throw error(.expectedComma)
                        }

                        wasComma = false

                        let type = try parseType()
                        types.append(type)
                    }

                default:
                    // FIXME(vdka): I have no idea what this should be D:
                    // I lost context here.
                    unimplemented()
                }
            }
            
            if wasComma { throw error(.unexpectedComma) }
            
            /// TODO(vdka): allow varargs `...`
            try consume(.rparen)
            try consume(.keyword(.returnArrow))
            
            /// TODO(vdka): @multiplereturns
            let returnType = try parseType()
            
            #if false
                while case (.comma, _)? = try lexer.peek() {
                    try consume(.comma)
                    let nextType = try parseType()
                    returnTypes.append(nextType)
                }
            #endif
            
            let procInfo = ProcInfo(labels: labels, params: types, returns: [returnType])
            return AST.Node(.procType(procInfo))

        default: // TODO(vdka): Report errors
            return AST.Node(.invalid)
        }
    }
}
