
extension Parser {

	mutating func parseImportDirective() throws -> AstNode {
		let (_, directiveLocation) = try consume(.directive(.import))

        guard case (.literal(let path), let pathLocation)? = try lexer.peek() else {
            reportError("Expected filename as string literal", at: lexer.lastLocation)
            return AstNode.invalid(directiveLocation)
        }

        try consume() // .literal("filepath")

        let pathNode = AstNode.literal(.basic(path, pathLocation))

        let fullPath = resolveToFullPath(relativePath: path)

        guard let (token, aliasLocation) = try lexer.peek() else {

            // TODO(vdka): check if we're importing a directory, if so, then the basedir should be the importName
            return AstNode.decl(.import(relativePath: pathNode, fullPath: fullPath, importName: nil, directiveLocation))
        }

        switch token {
        case .ident(let alias):

            let aliasNode = AstNode.ident(alias, aliasLocation)
            return AstNode.decl(.import(relativePath: pathNode, fullPath: fullPath, importName: aliasNode, directiveLocation))

            // TODO(vdka): import into current namespace.
            // possibly with? I don't think it works
            /*
             #import "fmt.kai"
             using fmt
            */
        default:
            return AstNode.decl(.import(relativePath: pathNode, fullPath: fullPath, importName: nil, directiveLocation))
        }
	}
}
