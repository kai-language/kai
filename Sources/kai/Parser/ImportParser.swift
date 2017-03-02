
import Foundation.NSFileManager

extension Parser {

	mutating func parseImportDirective() throws -> AstNode {
		let (_, directiveLocation) = try consume(.directive(.import))

        guard case (.string(let path), let pathLocation)? = try lexer.peek() else {
            reportError("Expected filename as string literal", at: lexer.lastLocation)
            return AstNode.invalid(directiveLocation)
        }

        try consume() // .literal("filepath")

        let pathNode = AstNode.literal(.basic(.string(path), pathLocation))

        // If we can't resolve an import it will be caught later in the checker.
        let fullPath = FileManager.default.absolutePath(for: path) ?? "_"

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
