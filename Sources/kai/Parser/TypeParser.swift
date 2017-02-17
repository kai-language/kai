
extension Parser {

    mutating func parseType() throws -> KaiType {

        // TODO(vdka): How would dynamic procedure creation work?
        //  somethingStrange :: (x: Int, y: typeof(someFoo)) -> Int { /* ... */ }
        if case .identifier(let id)? = try lexer.peek()?.kind {
            try consume()

            return .unknown(id)
        }

        try consume(.lparen)

        var wasComma = false


        // TODO(vdka): no need for the bool here, either we expect to have label's or not.
        var labels: [(callsite: ByteString?, binding: ByteString)]? = []
        if case (.identifier(_)?, .comma?) = try (lexer.peek()?.kind, lexer.peek(aheadBy: 1)?.kind) {
            labels = nil // we do not expect any labels.
        }

        var types: [KaiType] = []
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

            let returnType = try parseType()
            return .procedure(labels: labels, types: types, returnType: returnType)
        } else {

            unimplemented("Tuple are not yet supported")
        }
    }
}
