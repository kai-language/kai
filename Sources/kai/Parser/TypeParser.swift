
extension Parser {

    mutating func parseType() throws -> TypeRecord {

        // TODO(vdka): How would dynamic procedure creation work?
        //  somethingStrange :: (x: Int, y: typeof(someFoo)) -> Int { /* ... */ }
        if case .identifier(let id)? = try lexer.peek()?.kind {
            try consume()

            // The kind is invalid until it is resolved by the type solver.
            return TypeRecord(name: id.string, kind: .invalid)
        }

        try consume(.lparen)

        var wasComma = false


        var labels: [(callsite: ByteString?, binding: ByteString)]? = []
        if case (.identifier(_)?, .comma?) = try (lexer.peek()?.kind, lexer.peek(aheadBy: 1)?.kind) {
            labels = nil // we do not expect any labels.
        }

        var types: [TypeRecord] = []
        while let token = try lexer.peek(), token.kind != .rparen {
            if case .comma = token.kind {

                if types.isEmpty || wasComma { try error(.unexpectedComma).recover(with: &self) }

                wasComma = true

                try consume(.comma)
            } else if case .underscore = token.kind,
                case .identifier(let binding)? = try lexer.peek(aheadBy: 1)?.kind,
                case .colon? = try lexer.peek(aheadBy: 2)?.kind {

                if types.isEmpty && wasComma { throw error(.unexpectedComma) }
                if !types.isEmpty && !wasComma { throw error(.expectedComma) }
                if labels == nil { throw error(.syntaxError) } // TODO(vdka): Better message

                wasComma = false

                try consume(.underscore)
                try consume() // .identifier(_)
                try consume(.colon)

                labels?.append((callsite: nil, binding: binding))

                let type = try parseType()
                types.append(type)
            } else if case .identifier(let callsite) = token.kind,
                case .identifier(let binding)? = try lexer.peek(aheadBy: 1)?.kind,
                case .colon? = try lexer.peek(aheadBy: 2)?.kind {

                if types.isEmpty && wasComma { throw error(.unexpectedComma) }
                else if !types.isEmpty && !wasComma { throw error(.expectedComma) }
                if labels == nil { throw error(.syntaxError) } // TODO(vdka): Better message

                wasComma = false

                try consume() // .identifier(_)
                try consume() // .identifier(_)
                try consume(.colon)

                labels?.append((callsite: callsite, binding: binding))

                let type = try parseType()
                types.append(type)
            } else if case .identifier(let binding) = token.kind,
                case .colon? = try lexer.peek(aheadBy: 1)?.kind {

                if types.isEmpty && wasComma { throw error(.unexpectedComma) }
                else if !types.isEmpty && !wasComma { throw error(.expectedComma) }
                if labels == nil { throw error(.syntaxError) } // TODO(vdka): Better message

                wasComma = false

                try consume() // .identifier(_)
                try consume(.colon)

                labels?.append((callsite: binding, binding: binding))

                let type = try parseType()
                types.append(type)
            } else {

                if types.isEmpty && wasComma { throw error(.unexpectedComma) }
                else if !types.isEmpty && !wasComma { throw error(.expectedComma) }

                wasComma = false

                let type = try parseType()
                types.append(type)
            }
        }

        if wasComma { throw error(.unexpectedComma) }

        try consume(.rparen)
        if case .keyword(.returnType)? = try lexer.peek()?.kind {
            try consume(.keyword(.returnType))

            /// TODO(vdka): @multiplereturns
            /// TODO(vdka): @varargs
            let returnType = try parseType()

            let procInfo = TypeRecord.ProcInfo(labels: labels, params: types, returns: [returnType])
            return TypeRecord(kind: .proc(procInfo))
        } else {

            unimplemented("Tuple are not yet supported")
        }
    }
}
