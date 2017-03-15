
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

        case .lbrack, .lparen, .dot:
            return 20

        case .colon, .equals:
            return 160

        case .comma where state.contains(.disallowComma):
            return 0

        case .comma:
            return 180

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
            state.remove(.disallowComma)

            let (_, lLocation) = try consume(.lparen)
            let expr = try expression()
            let (_, rLocation) = try consume(.rparen)

            return AstNode.exprParen(expr, lLocation ..< rLocation)

        case .keyword(.if):
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
            let (_, _) = try consume(.keyword(.for))

            // NOTE(vdka): for stmt bodies *must* be braced
            var expressions: [AstNode] = []
            while try lexer.peek()?.kind != .lparen {
                let expr = try expression()
                expressions.append(expr)
            }

            let body = try expression()

            expressions.append(body)

            unimplemented("for loops")

        case .keyword(.break):
            let (_, startLocation) = try consume(.keyword(.break))
            return AstNode.stmtBreak(startLocation ..< lexer.location)

        case .keyword(.continue):
            let (_, startLocation) = try consume(.keyword(.continue))
            return AstNode.stmtContinue(startLocation ..< lexer.location)

        case .keyword(.return):
            let (_, startLocation) = try consume(.keyword(.return))

            // TODO(vdka): parseMultiple comma seperated expr's
            // FIXME(vdka): This will fail pretty badly if the return is not the last stmt in the block
            // TODO(vdka): Validate that our current context permits return statements
            var exprs: [AstNode] = []
            while try lexer.peek()?.kind != .rbrace {
                let expr = try expression()
                exprs.append(expr)
                if case .comma? = try lexer.peek()?.kind {
                    try consume(.comma)
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

            if case .ident("as")? = try lexer.peek()?.kind {
                guard case .ident(let alias)? = try lexer.peek()?.kind else {
                    reportError("Expected identifier for import alias", at: lexer.lastLocation)
                    return AstNode.invalid(location ..< lexer.lastLocation)
                }
                try consume()

                let aliasNode = AstNode.ident(alias, lexer.lastConsumedRange)
                return AstNode.declImport(path: pathNode, fullpath: fullpath, importName: aliasNode, location ..< lexer.location)
            }

            let node = AstNode.declImport(path: pathNode, fullpath: fullpath, importName: nil, location ..< pathNode.endLocation)

            // bad paths are reported in the checker
            if let fullpath = fullpath {
                let importedFile = ImportedFile(fullpath: fullpath, node: node)
                imports.append(importedFile)
            }

            return node

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

                guard let (token, _) = try lexer.peek() else {
                    reportError("Expected an initial value for type infered declaration", at: lvalue)
                    return AstNode.invalid(lvalue.location)
                }

                switch token {
                case .keyword(.struct),
                     .keyword(.enum):

                    unimplemented("parsing struct and enum type declarations")

                case .lparen: // litProc or a exprParen `x :: () -> void` | `(5)`
                    let (_, lparen) = try consume()

                    // Q(vdka): Do we want to outlaw `()` in favor of always requiring a type within `(void)`? Is that just being authoritarian?
                    if case .rparen? = try lexer.peek()?.kind { // `some :: () -> void` no arg procedures
                        try consume(.rparen)

                        try consume(.keyword(.returnArrow))
                        let resultType = try parseType()
                        let type = AstNode.typeProc(params: [], results: explode(resultType), lparen ..< resultType.endLocation)

                        let body = try expression()

                        let litProc = AstNode.litProc(type: type, body: body, type.startLocation ..< body.endLocation)
                        return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [litProc], lvalue.startLocation ..< litProc.endLocation)
                    }

//                    let prevState = state
//                    state.insert(.disallowComma)

                    let expr = try expression()
//                    state = prevState

                    if case .comma? = try lexer.peek()?.kind { // `(x: f32, `
                        guard case .declValue = expr else {
                            panic("Shouldn't happen") // syntax error? `x :: (x, y) // no tuples`
                        }

                        var args: [AstNode] = [expr]

                        while case .comma? = try lexer.peek()?.kind {
                            try consume(.comma)

                            let arg = try expression()
                            args.append(arg)
                        }

                        try consume(.rparen)

                        try consume(.keyword(.returnArrow))
                        let resultType = try parseType()
                        let type = AstNode.typeProc(params: args, results: explode(resultType), lparen ..< resultType.endLocation)

                        let body = try expression()

                        let litProc = AstNode.litProc(type: type, body: body, range(from: type, toEndOf: body))
                        return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [litProc], lvalue.startLocation ..< litProc.endLocation)
                    }

                    let (_, rparen) = try consume(.rparen)

                    if case .keyword(.returnArrow)? = try lexer.peek()?.kind {

                        try consume(.keyword(.returnArrow)) // .returnArrow

                        let resultType = try parseType()
                        let type = AstNode.typeProc(params: explode(expr), results: explode(resultType), lparen ..< resultType.endLocation)

                        let body = try expression() // TODO(vdka): If this fails it should error with a message about assigning values to proc types


                        let litProc = AstNode.litProc(type: type, body: body, range(from: type, toEndOf: body))
                        return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: [litProc], lvalue.startLocation ..< litProc.endLocation)
                    }

                    return AstNode.exprParen(expr, lparen ..< rparen)

                default:
                    let rvalue = try expression()
                    return AstNode.declValue(isRuntime: false, names: explode(lvalue), type: nil, values: explode(rvalue), lvalue.startLocation ..< lexer.location)
                }


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

        default:
            unimplemented()
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
