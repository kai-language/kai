
import Foundation.NSFileManager
/*
typedef struct Parser {
    String              init_fullpath;
    Array(AstFile)      files;
    Array(ImportedFile) imports;
    gbAtomic32          import_index;
    isize               total_token_count;
    isize               total_line_count;
    gbMutex             mutex;
} Parser;

typedef struct ImportedFile {
    String   path;
    String   rel_path;
    TokenPos pos; // #import
} ImportedFile;

// parse_files
for_array(i, p->imports) {
    ImportedFile imported_file = p->imports.e[i];
    String import_path = imported_file.path;
    String import_rel_path = imported_file.rel_path;
    TokenPos pos = imported_file.pos;
    AstFile file = {0};

    ParseFileError err = init_ast_file(&file, import_path);

    if (err != ParseFile_None) {
        desc(err);
        return err;
    }
    parse_file(p, &file);

    {
        gb_mutex_lock(&p->mutex);
        file.id = p->files.count;
        array_add(&p->files, file);
        p->total_line_count += file.tokenizer.line_count;
        gb_mutex_unlock(&p->mutex);
    }
}
*/

struct ImportedFile {
    var fullPath: String
    var relativePath: String
    // TODO(vdka): source token (for location)

    init?(relativePath: String) {
        guard let fullPath = FileManager.default.absolutePath(for: relativePath) else {
            return nil
        }
        self.fullPath = fullPath
        self.relativePath = relativePath
    }
}

struct Parser {

    var basePath: String = ""
    var files: [ASTFile] = []
    var imports: [ImportedFile] = []

    var lexer: Lexer!

    // TODO(vdka): Remove
    var context = Context()

    var errors: UInt = 0

    init(relativePath: String) {

        self.files = []

        // FIXME(vdka): Ensure bad build file path's do not get to the Parser initialization call.
        let importedFile = ImportedFile(relativePath: relativePath)!

        self.imports = [importedFile]
    }

    mutating func parseFiles() throws -> [ASTFile] {

        for importFile in imports {

            let fileNode = ASTFile(named: importFile.fullPath)
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

        // TODO(vdka): Allow comma's based of parser state
//        if case .comma? = try lexer.peek()?.kind, context.allowCommas {
//            return left
//        }

        while let (nextToken, _) = try lexer.peek(), let lbp = lbp(for: nextToken),
            rbp < lbp
        {
            left = try led(for: nextToken, with: left)
        }

        return left
    }
}

extension Parser {

    mutating func lbp(for token: Lexer.Token) -> UInt8? {

        switch token {
        case .operator(let symbol):

            switch try? (lexer.peek(aheadBy: 1)?.kind, lexer.peek(aheadBy: 2)?.kind) {
            case (.colon?, .colon?)?:
                return 0

            default:
                return Operator.table.first(where: { $0.symbol == symbol })?.lbp
            }

        case .colon:
            return UInt8.max

        case .comma:
            return 180

        case .equals:
            return 160

        case .lbrack, .lparen, .dot:
            return 20

        default:
            return 0
        }
    }

    mutating func nud(for token: Lexer.Token) throws -> AstNode {

        switch token {
        case .operator(let symbol):
            guard let nud = Operator.table.first(where: { $0.symbol == symbol })?.nud else {
                throw error(.nonInfixOperator(token))
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

            /*
             z :: (x + y)
             z :: (f32) -> f32 #foreign libc
             z :: (x: f32) -> f32 { /* .. */ }
            */

            let (_, lLocation) = try consume(.lparen)
            let expr = try expression()
            let (_, rLocation) = try consume(.rparen)

            // TODO(vdka):
            /*
             (x * y)
             vs
             (x: int) -> foo {
                something else?
             }
            */

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
            let (_, startLocation) = try consume(.keyword(.for))

            // NOTE(vdka): for stmt bodies *must* be braced
            var expressions: [AstNode] = []
            while try lexer.peek()?.kind != .lparen {
                let expr = try expression()
                expressions.append(expr)
            }

            push(context: .loopBody)
            defer { popContext() }

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
            return try parseImportDirective()

        default:
            fatalError()
        }
    }

    mutating func led(for token: Lexer.Token, with lvalue: AstNode) throws -> AstNode {

        switch token {
        case .operator(let symbol):
            guard let led = Operator.table.first(where: { $0.symbol == symbol })?.led else {
                throw error(.nonInfixOperator(token))
            }
            return try led(&self, lvalue)

        case .dot:
            let (_, location) = try consume(.dot)

            guard case (.ident(let member), let memberLocation)? = try lexer.peek() else {
                throw error(.expectedMemberName)
            }

            try consume() // .ident(_)

            let rvalue = AstNode.ident(member, memberLocation ..< lexer.location)

            return AstNode.exprSelector(receiver: lvalue, member: rvalue, location ..< lexer.location)

        case .comma:
            // TODO(vdka): Check if `context.contains(.allowComma)` (made up call)
            let (_, location) = try consume(.comma)
            reportError("Unexpected comma", at: location)
            return AstNode.invalid(location ..< location)

        case .lparen:
            return try parseProcedureCall(lvalue)

        case .equals:

            let (_, location) = try consume(.equals)

            let rvalue = try expression()

            // TODO(vdka): Handle multiple expressions. That gon be herd.
            //   Actually this isn't a decl so, maybe we don't support this.
            /* x, y, z = z, y, x */
            // Maybe we prefer
            /* (x, y, z) = (z, y, x) */
            // where l & r values would be field lists. This is probably easier to parse, but what is the most syntactially constant.

            return AstNode.stmtAssign("=", lhs: [lvalue], rhs: [rvalue], lvalue.startLocation ..< rvalue.endLocation)

        case .colon:
            try consume(.colon)
            switch try lexer.peek()?.kind {
            case .colon?: // type infered compiletime decl
                try consume(.colon)

                guard let (token, _) = try lexer.peek() else {
                    throw error(.invalidDeclaration)
                }

                switch token {
                case .keyword(.struct),
                     .keyword(.enum):

                    unimplemented("parsing struct and enum type declarations")

                    /*
                        tau :: (pi * 2), wtfareyoudoing
                        abs :: (f32) -> f32 #foreign libc "fabs" // not supported right now.
                        hypot :: (x: f32, y: f32) -> f32 #foreign libc "hypotf"
                        tau :: (pi * 2), secondVar, wtfAreYouDoingHaveAParserError
                    */
                case .lparen: // litProc or a exprParen `() -> void` | `(5)`
                    let (_, lparen) = try consume()

                    if case .rparen? = try lexer.peek()?.kind { // `some :: () -> void` NOTE(vdka): `()` is not valid.
                        let (_, rparen) = try consume(.rparen)

                        let argumentList = AstNode.list([], lparen ..< rparen)

                        try consume(.keyword(.returnArrow))
                        let resultType = try parseType()
                        let type = AstNode.typeProc(params: argumentList, results: resultType, range(from: argumentList, toEndOf: resultType))

                        let body = try expression()
                        return AstNode.litProc(type: type, body: body, range(from: type, toEndOf: body))
                    }

                    let expr = try expression()

                    if case .comma? = try lexer.peek()?.kind { // `(x: f32, `
                        guard case .declValue = expr else {
                            fatalError("Shouldn't happen") // syntax error? `x :: (x, y) // no tuples`
                        }

                        var exprs: [AstNode] = [expr]

                        while case .comma? = try lexer.peek()?.kind {
                            try consume(.comma)

                            let expr = try expression()
                            exprs.append(expr)
                        }

                        let (_, rparen) = try consume(.rparen)

                        let fields = exprs.flatMap(convertDeclValueToArgs)
                        let argumentList = AstNode.list(fields, lparen ..< rparen)

                        try consume(.keyword(.returnArrow))
                        let resultType = try parseType()
                        let type = AstNode.typeProc(params: argumentList, results: resultType, range(from: argumentList, toEndOf: resultType))

                        let body = try expression()
                        return AstNode.litProc(type: type, body: body, range(from: type, toEndOf: body))
                    }

                    let (_, rparen) = try consume(.rparen)

                    if case .keyword(.returnArrow)? = try lexer.peek()?.kind {
                        let field = convertDeclValueToArgs(expr)
                        let argumentList = AstNode.list(field, lparen ..< rparen)

                        try consume(.keyword(.returnArrow)) // .returnArrow
                        let resultType = try parseType()
                        let type = AstNode.typeProc(params: argumentList, results: resultType, range(from: argumentList, toEndOf: resultType))

                        let body = try expression() // TODO(vdka): If this fails it should error with a message about assigning values to proc types
                        return AstNode.litProc(type: type, body: body, range(from: type, toEndOf: body))
                    }

                    return AstNode.exprParen(expr, lparen ..< rparen)

                default:
                    let rvalues = try parseMultipleExpressions()
                    return AstNode.declValue(isRuntime: false, names: [lvalue], type: nil, values: rvalues, lvalue.startLocation ..< lexer.location)
                }


            case .equals?: // type infered runtime decl
                try consume(.equals)
                let rvalues = try parseMultipleExpressions()
                return AstNode.declValue(isRuntime: true, names: [lvalue], type: nil, values: rvalues, lvalue.startLocation ..< lexer.location)

            default: // type is provided `x : int`

                let type = try parseType()

                switch try lexer.peek()?.kind {
                case .colon?:
                    // NOTE(vdka): We should report prohibitted type specification at least in some cases. ie: `Foo : typeName : struct { ... }` doesn't make sense
                    unimplemented("Explicit type for compile time declarations")

                case .equals?: // `x : int = y` | `x, y : int = 1, 2`
                    let rvalues = try parseMultipleExpressions()
                    return AstNode.declValue(isRuntime: true, names: [lvalue], type: type, values: rvalues, lvalue.startLocation ..< lexer.location)

                default: // `x : int` | `x, y, z: f32`
                    return AstNode.declValue(isRuntime: true, names: [lvalue], type: type, values: [], lvalue.startLocation ..< lexer.location)
                }
            }

            /*
            if case .colon? = try lexer.peek(aheadBy: 1)?.kind { // '::'
                // TODO(vdka): Check that the lvalue is an ident or report an error
                return try parseCompileTimeDeclaration(lvalue)
            }

            try consume(.colon)

            switch try lexer.peek()?.kind {
            case .equals?:
                // type is infered
                let (_, location) = try consume(.equals)
                let rvalues = try parseMultipleExpressions()

                // TODO(vdka): handle mismatched lhs count and rhs count

                // TODO(vdka): Multiple declarations

                return AstNode.declValue(isRuntime: true, names: [lvalue], type: nil, values: rvalues, lvalue.startLocation ..< lexer.location)

            default:

                // NOTE(vdka): For now you can only have a single type on the lhs
                // TODO(vdka): This should have a warning to explain.
                let type = try parseType()
                let (_, location) = try consume(.equals)
                let rvalues = try parseMultipleExpressions()

                return AstNode.declValue(isRuntime: true, names: [lvalue], type: type, values: rvalues, location ..< lexer.location)
            }
            */

        default:
            unimplemented()
        }
    }


    // MARK: Sub parsers

    mutating func parseMultipleExpressions() throws -> [AstNode] {

        let expr = try expression()
        var exprs: [AstNode] = [expr]

        while case .comma? = try lexer.peek()?.kind {
            try consume(.comma)

            let expr = try expression()
            exprs.append(expr)
        }

        return exprs
    }

    mutating func parseFieldList() throws -> AstNode {
        let (_, _) = try consume(.lparen)
        var wasComma = false

        var fields: [AstNode] = []

        // TODO(vdka): Add support for labeled fields (Only relivant to type decl names)?

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
                try consume()
                let nameNode = AstNode.ident(name, location ..< lexer.location)
                var names = [nameNode]
                while case (.comma, _)? = try lexer.peek() {

                    try consume(.comma)
                    guard case (.ident(let name), let location)? = try lexer.peek() else {
                        reportError("Expected identifier", at: lexer.lastConsumedRange)
                        try consume()
                        continue
                    }

                    let nameNode = AstNode.ident(name, location ..< lexer.location)
                    names.append(nameNode)
                }

                try consume(.colon)
                let type = try parseType()
                let newFields = names.map({ AstNode.field(name: $0, type: type, $0.location) })
                fields.append(contentsOf: newFields)

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

        return AstNode.list(fields, lexer.lastConsumedRange)
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
            throw error(.expected("something TODO ln Parser.swift:324"), location: try lexer.peek()!.location)
        }

        return try lexer.pop()
    }

    func convertDeclValueToArgs(_ decl: AstNode) -> [AstNode] {
        guard case .declValue(let decl) = decl else {
            preconditionFailure() // TODO(vdka): Report error
        }

        assert(decl.values.isEmpty) // `(x: int = 5) -> int
                                    //            - default values unsupported

        assert(decl.type != nil) // TODO(vdka): if the decl type is nil then maybe the user has done: `(x := 5) -> int`

        return decl.names.map({ AstNode.field(name: $0, type: decl.type!, $0.location) })
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
