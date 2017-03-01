
extension Parser {

    mutating func parseType() throws -> AstNode {
        guard let (token, startLocation) = try lexer.peek() else {
            reportError("Expected a type", at: lexer.lastLocation)
            return AstNode.invalid(lexer.lastLocation)
        }

        switch token {
        case .ident(let ident):
            try consume()

            return AstNode.ident(ident, startLocation)

        case .lparen:
            try consume(.lparen)
            var wasComma = false

            var fields: [AstNode] = []

            // TODO(vdka): Add support for labeled fields

            while let (token, location) = try lexer.peek(), token != .rparen {

                switch token {
                case .comma:
                    try consume(.comma)
                    if fields.isEmpty && wasComma {
                        reportError("Unexpected comma", at: location)
                        continue
                    }

                    wasComma = true

                case .ident(let name):
                    try consume() // .ident
                    
                    let nameNode = AstNode.ident(name, location)
                    var names = [nameNode]
                    while case (.comma, _)? = try lexer.peek() {

                        try consume(.comma)
                        guard case (.ident(let name), let location)? = try lexer.peek() else {
                            reportError("Expected identifier", at: lexer.lastLocation)
                            try consume()
                            continue
                        }

                        let nameNode = AstNode.ident(name, location)
                        names.append(nameNode)
                    }

                    try consume(.colon)
                    let type = try parseType()
                    let field = AstNode.field(names: names, type: type, startLocation)
                    fields.append(field)

                    wasComma = false

                default:
                    if wasComma {
                        // comma with no fields
                        reportError("Unexpected comma", at: location)
                    }

                    wasComma = false
                }
            }

            try consume(.rparen)

            let fieldList = AstNode.fieldList(fields, startLocation)

            guard let (token, _) = try lexer.peek() else {
                // allow `someVars : (x: int, y: int)` at the end of a file
                return fieldList
            }

            switch token {
            case .keyword(.returnArrow):
                try consume(.keyword(.returnArrow))
                let retType = try parseType()

                return AstNode.type(.proc(params: fieldList, results: retType, startLocation))

            default:
                return fieldList
            }

        default:
            reportError("Expected type literal", at: startLocation)
        }
        
        return AstNode.invalid(startLocation)
    }
}
