
import Foundation.NSFileManager

extension Parser {

	mutating func parseImportDirective() throws -> AstNode {
		let (_, directiveLocation) = try consume(.directive(.import))

        guard case (.string(let path), let pathLocation)? = try lexer.peek() else {
            reportError("Expected filename as string literal", at: lexer.lastLocation)
            return AstNode.invalid(directiveLocation ..< lexer.location)
        }

        try consume() // .literal("filepath")

        let pathNode = AstNode.litString(path, pathLocation ..< lexer.location)

        // If we can't resolve an import it will be caught later in the checker.
        let fullpath = FileManager.default.absolutePath(for: path) ?? "_"

        guard let (token, aliasLocation) = try lexer.peek() else {

            // TODO(vdka): check if we're importing a directory, if so, then the basedir should be the importName
            return AstNode.declImport(relPath: pathNode, fullpath: fullpath, importName: nil, directiveLocation ..< lexer.location)
        }

        switch token {
        case .ident(let alias):
            try consume()

            let aliasNode = AstNode.ident(alias, aliasLocation ..< lexer.location)
            return AstNode.declImport(relPath: pathNode, fullpath: fullpath, importName: aliasNode, directiveLocation ..< lexer.location)

        default:
            return AstNode.declImport(relPath: pathNode, fullpath: fullpath, importName: nil, directiveLocation ..< lexer.location)
        }
	}
}
