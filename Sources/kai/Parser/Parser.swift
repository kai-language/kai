
import Foundation.NSFileManager

struct ImportedFile {
    var fullpath: String
    var node: AstNode
}

struct Parser {

    var basePath: String = ""
    var files: [ASTFile] = []
    var imports: [ImportedFile] = []

    var lexer: Lexer!
    var state: State = .default

    init(relativePath: String) {

        self.files = []

        let initPath = FileManager.default.absolutePath(for: relativePath)!

        // FIXME(vdka): Ensure bad build file path's do not get to the Parser initialization call.
        let importedFile = ImportedFile(fullpath: initPath, node: AstNode.invalid(SourceLocation.unknown ..< SourceLocation.unknown))

        self.imports = [importedFile]
    }

    var currentFile: ASTFile! {
        return files.last!
    }

    struct State: ExpressibleByIntegerLiteral, OptionSet {
        let rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }
        init(integerLiteral value: UInt8) { self.rawValue = value }

        static let `default`:     State = 0b0000
        static let disallowComma: State = 0b0001
    }
}

// MARK: Functionality

extension Parser {

    mutating func parseFiles() throws -> [ASTFile] {

        while let importFile = imports.popLast() {

            let fileNode = ASTFile(named: importFile.fullpath)
            files.append(fileNode)

            try parse(file: fileNode)
        }

        return files
    }

    mutating func parse(file: ASTFile) throws {

        lexer = file.lexer

        // TODO(vdka): Add imported files into the imports
        while try lexer.peek() != nil {

            let node = try expression()

            // TODO(vdka): Report errors for invalid global scope nodes
            file.nodes.append(node)
        }
    }

    mutating func expression(_ rbp: UInt8 = 0) throws -> AstNode {

        // TODO(vdka): Still unclear what to do with empty files
        guard let (token, _) = try lexer.peek() else { return AstNode.invalid(lexer.lastLocation ..< lexer.lastLocation) }

        var left = try nud(for: token)

        while let (nextToken, _) = try lexer.peek(), let lbp = lbp(for: nextToken),
            rbp < lbp
        {
            left = try led(for: nextToken, with: left)
            if case .declValue = left { break }
        }

        return left
    }
}

extension Parser {

    mutating func lbp(for token: Lexer.Token) -> UInt8? {

        switch token {
        case .operator(let symbol):
            return Operator.table.first(where: { $0.symbol == symbol })?.lbp

        case .lbrack, .lparen:
            return 160

        case .colon, .equals:
            return 160

        case .comma where state.contains(.disallowComma):
            return 0

        case .comma:
            return 180

        case .dot:
            return 190

        case .keyword(.returnArrow):
            return 200 // TODO(vdka): Work out actual value.

        default:
            return 0
        }
    }

    mutating func nud(for token: Lexer.Token) throws -> AstNode {

        switch token {
        case .operator(let symbol):
            guard let nud = Operator.table.first(where: { $0.symbol == symbol })?.nud else {
                let (_, location) = try consume()
                reportError("Non prefix operator", at: location)
                let expr = try expression()
                return AstNode.invalid(location ..< expr.endLocation)
            }
            return try nud(&self)

        case .ident(let symbol):
            let (_, location) = try consume()
            return AstNode.ident(symbol, location ..< lexer.location)

        case .string(let string):
            let (_, location) = try consume()
            return AstNode.litString(string, location ..< lexer.location)

        case .integer(let int):
            let (_, location) = try consume()
            return AstNode.litInteger(int, location ..< lexer.location)

        case .float(let dbl):
            let (_, location) = try consume()
            return AstNode.litFloat(dbl, location ..< lexer.location)

        case .lparen:
            let prevState = state
            defer { state = prevState }
            state.insert(.disallowComma)

            let (_, lparen) = try consume(.lparen)
            if case .rparen? = try lexer.peek()?.kind {
                let (_, rparen) = try consume(.rparen)
                let empty = AstNode.stmtEmpty(lparen ..< rparen)
                return AstNode.exprParen(empty, lparen ..< rparen)
            }

            // Even if it's just a paran'd expr we have to entertain the possibility of something more. (parameter list)
            var wasComma = false
            var exprs: [AstNode] = []
            loop: while true {

                switch try lexer.peek()?.kind {
                case .rparen?:
                    break loop

                case .comma?:
                    let (_, location) = try consume(.comma)
                    if wasComma || exprs.isEmpty {
                        reportError("Unexpected comma", at: location)
                    }
                    wasComma = true

                default:
                    if !wasComma && !exprs.isEmpty {
                        break loop
                    }
                    let expr = try expression()
                    exprs.append(expr)
                    wasComma = false
                }
            }

            if wasComma {
                reportError("Unexpected comma", at: lexer.lastLocation)
            }

            let (_, rparen) = try consume(.rparen)
            if exprs.count == 1, let first = exprs.first {
                return AstNode.exprParen(first, lparen ..< rparen)
            } else {
                let listNode = AstNode.list(exprs, exprs.first!.startLocation ..< exprs.last!.endLocation)
                return AstNode.exprParen(listNode, lparen ..< rparen)
            }


        case .keyword(.if):
            // TODO(vdka): Support checking this: `if val, err := couldFail(); err == nil { /* ... */ }`
            // NOTE(vdka): With `;` it's unclear what the cond expr is (it's whatever the second last expr is.
            //   Instead we could use `,` to do this.

            let (_, startLocation) = try consume(.keyword(.if))

            let condExpr = try expression()
            let bodyExpr = try expression()

            guard case .keyword(.else)? = try lexer.peek()?.kind else {
                return AstNode.stmtIf(cond: condExpr, body: bodyExpr, nil, startLocation ..< bodyExpr.endLocation)
            }

            try consume(.keyword(.else))
            let elseExpr = try expression()
            return AstNode.stmtIf(cond: condExpr, body: bodyExpr, elseExpr, startLocation ..< bodyExpr.endLocation)

        case .keyword(.for):
            let (_, location) = try consume(.keyword(.for))

            if case .lbrace? = try lexer.peek()?.kind {
                let body = try expression()

                return AstNode.stmtFor(initializer: nil, cond: nil, post: nil, body: body, location ..< body.endLocation)
            }

            var exprs: [AstNode] = []
            while exprs.count <= 3 {
                if case .semicolon? = try lexer.peek()?.kind {
                    try consume()
                    let emptyNode = AstNode.stmtEmpty(lexer.location ..< lexer.location)
                    exprs.append(emptyNode)
                    continue
                }

                let expr = try expression()

                exprs.append(expr)

                if case .semicolon? = try lexer.peek()?.kind {
                    try consume()
                }
                if case .lbrace? = try lexer.peek()?.kind {
                    break
                }
            }

            let body = try expression()

            switch exprs.count {
            case 1:
                return AstNode.stmtFor(initializer: nil, cond: exprs[0], post: nil, body: body, location ..< body.endLocation)

            case 3:
                return AstNode.stmtFor(initializer: exprs[safe: 0], cond: exprs[safe: 1], post: exprs[safe: 2], body: body, location ..< body.endLocation)

            default:
                reportError("For statements require 0, 1 or 3 statements", at: location ..< body.startLocation)
                return AstNode.invalid(location ..< body.endLocation)
            }

        case .keyword(.break):
            let (_, startLocation) = try consume(.keyword(.break))
            return AstNode.stmtBreak(startLocation ..< lexer.location)

        case .keyword(.continue):
            let (_, startLocation) = try consume(.keyword(.continue))
            return AstNode.stmtContinue(startLocation ..< lexer.location)

        case .keyword(.return):
            let prevState = state
            defer { state = prevState }
            state.insert(.disallowComma)

            let (_, startLocation) = try consume(.keyword(.return))
            var wasComma = false
            var exprs: [AstNode] = []
            loop: while true {

                switch try lexer.peek()?.kind {
                case .semicolon?, .rbrace?:
                    break loop

                case .comma?:
                    let (_, location) = try consume(.comma)
                    if wasComma || exprs.isEmpty {
                        reportError("Expected expression", at: location)
                    }
                    wasComma = true

                default:
                    if !wasComma && !exprs.isEmpty {
                        break loop
                    }
                    let expr = try expression()
                    exprs.append(expr)
                    wasComma = false
                }
            }
            return AstNode.stmtReturn(exprs, startLocation ..< lexer.location)

        case .keyword(.defer):
            let (_, startLocation) = try consume(.keyword(.defer))
            let expr = try expression()
            return AstNode.stmtDefer(expr, startLocation ..< lexer.location)

        case .lbrace:
            let (_, startLocation) = try consume(.lbrace)

            var stmts: [AstNode] = []
            while let next = try lexer.peek()?.kind, next != .rbrace {
                let stmt = try expression()
                stmts.append(stmt)
            }

            let (_, endLocation) = try consume(.rbrace)

            return AstNode.stmtBlock(stmts, startLocation ..< endLocation)

        case .directive(.file):
            let (_, location) = try consume()
            return AstNode.directive("file", args: [], location ..< lexer.location)

        case .directive(.line):
            let (_, location) = try consume()
            return AstNode.directive("line", args: [], location ..< lexer.location)

        case .directive(.import):
            let (_, location) = try consume()

            guard case .string(let path)? = try lexer.peek()?.kind else {
                reportError("Expected filename as string literal", at: lexer.lastLocation)
                return AstNode.invalid(location ..< lexer.location)
            }
            try consume() // .string("file.kai")

            let pathNode = AstNode.litString(path, lexer.lastConsumedRange)


            let fullpath = FileManager.default.absolutePath(for: path, relativeTo: currentFile)

            var node: AstNode
            switch try lexer.peek()?.kind {
            case .dot?:
                try consume()

                let aliasNode = AstNode.ident(".", lexer.lastConsumedRange)

                node = AstNode.declImport(path: pathNode, fullpath: fullpath, importName: aliasNode, location ..< lexer.location)

            case .ident(let name)?:
                try consume()

                let aliasNode = AstNode.ident(name, lexer.lastConsumedRange)
                node = AstNode.declImport(path: pathNode, fullpath: fullpath, importName: aliasNode, location ..< lexer.location)

            default:
                node = AstNode.declImport(path: pathNode, fullpath: fullpath, importName: nil, location ..< pathNode.endLocation)
            }

            // bad paths are reported in the checker
            if let fullpath = fullpath {
                let importedFile = ImportedFile(fullpath: fullpath, node: node)
                imports.append(importedFile)
            }

            return node

        case .directive(.library):
            let (_, location) = try consume()

            guard case .string(let path)? = try lexer.peek()?.kind else {
                reportError("Expected library path (or name) as a string", at: location)
                return AstNode.invalid(location ..< lexer.lastLocation)
            }
            try consume() // .string("file.dylib")

            let pathNode = AstNode.litString(path, lexer.lastConsumedRange)

            let fullpath = FileManager.default.absolutePath(for: path, relativeTo: currentFile)

            if case .ident(let alias)? = try lexer.peek()?.kind {

                try consume()

                let aliasNode = AstNode.ident(alias, lexer.lastConsumedRange)
                return AstNode.declLibrary(path: pathNode, fullpath: fullpath, libName: aliasNode, location ..< aliasNode.endLocation)
            }

            return AstNode.declLibrary(path: pathNode, fullpath: fullpath, libName: nil, location ..< pathNode.endLocation)

        case .keyword(.struct),
             .keyword(.enum):

            unimplemented("parsing struct and enum type declarations")

        default:
            panic(lexer)
        }
    }

    mutating func led(for token: Lexer.Token, with lvalue: AstNode) throws -> AstNode {

        switch token {
        case .operator(let symbol):
            guard let led = Operator.table.first(where: { $0.symbol == symbol })?.led else {
                reportError("Non infix operator \(symbol)", at: lexer.lastLocation)
                let rhs = try expression() // NOTE(vdka): Maybe we need some default precedence?
                return AstNode.invalid(lvalue.startLocation ..< rhs.endLocation)
            }
            return try led(&self, lvalue)

        case .dot:
            let (_, location) = try consume(.dot)

            guard case (.ident(let member), let memberLocation)? = try lexer.peek() else {
                reportError("Expected member name", at: lexer.lastLocation)
                return AstNode.invalid(location ..< location)
            }

            try consume() // .ident(_)

            let rvalue = AstNode.ident(member, memberLocation ..< lexer.location)

            return AstNode.exprSelector(receiver: lvalue, member: rvalue, location ..< lexer.location)

        case .comma:
            try consume()
            let bp = lbp(for: .comma)!
            let next = try expression(bp - 1) // allows chaining of `,`
            return append(lvalue, next)
 
        case .lparen:
            let (_, lparen) = try consume(.lparen)
            if case (.rparen, let rparen)? = try lexer.peek() {
                try consume(.rparen)
                return AstNode.exprCall(receiver: lvalue, args: [], lparen ..< rparen)
            }

            let args = try expression()

            let (_, rparen) = try consume(.rparen)
            return AstNode.exprCall(receiver: lvalue, args: explode(args), lparen ..< rparen)

        case .equals:

            try consume(.equals)

            let rvalue = try expression()

            return AstNode.stmtAssign("=", lhs: [lvalue], rhs: [rvalue], lvalue.startLocation ..< rvalue.endLocation)

        case .colon:
            try consume(.colon)
            switch try lexer.peek()?.kind {
            case .colon?: // type infered compiletime decl
                try consume(.colon)

                // FIXME(vdka): I expect we would crash when we call expression here at end of file

                let rvalue = try expression()

                return AstNode.declValue(isRuntime: false, names: explode(lvalue), type: nil, values: explode(rvalue), lvalue.startLocation ..< rvalue.endLocation)

            case .equals?: // type infered runtime decl
                try consume(.equals)
                let rvalue = try expression()
                return AstNode.declValue(isRuntime: true, names: explode(lvalue), type: nil, values: explode(rvalue), lvalue.startLocation ..< lexer.location)

            default: // type is provided `x : int`

                let type = try parseType()

                switch try lexer.peek()?.kind {
                case .colon?:
                    // NOTE(vdka): We should report prohibitted type specification at least in some cases. ie: `Foo : typeName : struct { ... }` doesn't make sense
                    unimplemented("Explicit type for compile time declarations")

                case .equals?: // `x : int = y` | `x, y : int = 1, 2`
                    try consume()
                    let rvalue = try expression()
                    return AstNode.declValue(isRuntime: true, names: explode(lvalue), type: type, values: explode(rvalue), lvalue.startLocation ..< lexer.location)

                default: // `x : int` | `x, y, z: f32`
                    return AstNode.declValue(isRuntime: true, names: explode(lvalue), type: type, values: [], lvalue.startLocation ..< lexer.location)
                }
            }

        // TODO(vdka): Make compile time decl's use this instead of the current special logic.
        case .keyword(.returnArrow):
            try consume()
            guard case .exprParen = lvalue else {
                reportError("Parameter lists must be surrounded by parenthesis", at: lvalue)
                return AstNode.invalid(lvalue.location)
            }
            let lvalue = unparenExpr(lvalue)

            if case (.lbrace, let location)? = try lexer.peek() { // `(n: int) ->`
                reportError("Expected return type", at: location)
                let expr = try expression() // consume the block statement
                return AstNode.invalid(lvalue.startLocation ..< expr.endLocation)
            }

            let results = try expression()
            let type = AstNode.typeProc(params: explode(lvalue), results: explode(results), lvalue.startLocation ..< results.endLocation)

            switch try lexer.peek()?.kind {
            case .lbrace?:
                let body = try expression()

                return AstNode.litProc(type: type, body: body, type.startLocation ..< body.endLocation)

            case .directive(.foreign)?: // #foreign libc "open"
                let (_, location) = try consume()

                guard case .ident(let libIdent)? = try lexer.peek()?.kind else {
                    reportError("Expected an identifier for library", at: lexer.location)
                    return AstNode.invalid(lvalue.startLocation ..< location)
                }
                try consume()

                let libNameNode = AstNode.ident(libIdent, lexer.lastConsumedRange)

                guard case .string(let path)? = try lexer.peek()?.kind else {
                    reportError("Expected path or special name for library", at: lexer.location)
                    return AstNode.invalid(lvalue.startLocation ..< location)
                }
                try consume()

                let libPathNode = AstNode.litString(path, lexer.lastConsumedRange)

                let directiveNode = AstNode.directive("foreign", args: [libNameNode, libPathNode], location ..< libNameNode.endLocation)

                return AstNode.litProc(type: type, body: directiveNode, lvalue.startLocation ..< directiveNode.endLocation)

            default:
                reportError("Procedure types cannot be used as values", at: type) // NOTE(vdka): Should this warn more about missing body in proc literal?
                return AstNode.invalid(type.location)
            }

        default:
            panic()
        }
    }

    mutating func parseType() throws -> AstNode {
        guard let (token, startLocation) = try lexer.peek() else {
            reportError("Expected a type", at: lexer.lastLocation)
            return AstNode.invalid(lexer.location ..< lexer.location)
        }

        if case .lparen = token {
            let prevState = state
            defer { state = prevState }
            state.remove(.disallowComma)
            let (_, lparen) = try consume()

            let expr = try expression()
            var exprs: [AstNode] = [expr]
            while case .comma? = try lexer.peek()?.kind {
                try consume()

                let expr = try expression()
                explode(expr)
                    .forEach({ exprs.append($0) })
                exprs.append(expr)
            }

            let (_, rparen) = try consume(.rparen)

            if case .keyword(.returnArrow)? = try lexer.peek()?.kind {
                try consume(.keyword(.returnArrow))

                let retType = try parseType()

                return AstNode.typeProc(params: exprs.flatMap(explode), results: explode(retType), startLocation ..< lexer.location)
            }
            
            return AstNode.list(exprs, lparen ..< rparen)
        }

        let prevState = state
        defer { state = prevState }
        state.insert(.disallowComma)
        return try expression(lbp(for: .colon)!)
    }
}


// - MARK: Helpers

extension Parser {

    @discardableResult
    mutating func consume(_ expected: Lexer.Token? = nil) throws -> (kind: Lexer.Token, location: SourceLocation) {
        guard let expected = expected else {
            // Seems we exhausted the token stream
            // TODO(vdka): Fix this up with a nice error message
            guard try lexer.peek() != nil else { fatalError() }
            return try lexer.pop()
        }

        guard try lexer.peek()?.kind == expected else {
            // FIXME(vdka): What is that error message. That's horrid.
            if let (actual, location) = try lexer.peek() {
                reportError("Expected \(expected), got \(actual) instead", at: location)
                return (.ident("<invalid>"), location)
            } else {
                reportError("Expected \(expected), but we reached the end of file", at: lexer.lastLocation)
                return (.ident("<invalid>"), lexer.lastLocation)
            }
        }

        return try lexer.pop()
    }

    func range(from a: AstNode?, toEndOf b: AstNode?) -> SourceRange {
        switch (a, b) {
        case let (a?, nil):
            return a.location

        case let (nil, b?):
            return b.location

        case let (a?, b?):
            return a.startLocation ..< b.endLocation

        case (nil, nil):
            return SourceLocation.unknown ..< SourceLocation.unknown
        }
    }

    func range(across nodes: [AstNode]) -> SourceRange {
        return range(from: nodes.first, toEndOf: nodes.last)
    }
}
