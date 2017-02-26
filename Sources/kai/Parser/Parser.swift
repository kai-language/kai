
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

    init(relativePath: String) {
        self.fullPath = resolveToFullPath(relativePath: relativePath)
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

        let importedFile = ImportedFile(relativePath: relativePath)

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
        while try file.lexer.peek() != nil {

            let node = try expression()

            // TODO(vdka): Report errors for invalid global scope nodes
            file.nodes.append(node)
        }
    }
//
//    mutating func parse() throws -> (AST, errors: UInt) {
//
//        let node = AST.Node(.file(name: lexer.scanner.file.name))
//
//        while true {
//            let expr: AST.Node
//            do {
//                expr = try expression()
//            } catch let error as Parser.Error {
//                try error.recover(with: &self)
//                continue
//            } catch { throw error }
//
//            guard expr.kind != .empty else { return (node, errors) }
//
//            node.children.append(expr)
//        }
//    }

    mutating func expression(_ rbp: UInt8 = 0) throws -> AST.Node {

        // TODO(vdka): This should probably throw instead of returning an empty node. What does an empty AST.Node even mean.
        guard let (token, location) = try lexer.peek() else { return AST.Node(.empty) }

        var left = try nud(for: token)
        left.location = location // NOTE(vdka): Is this generating incorrect locations?

        // operatorImplementation's need to be skipped too.
        if case .operatorDeclaration = left.kind { return left }
//        else if case .declaration(_) = left.kind { return left }
        else if case .comma? = try lexer.peek()?.kind, case .procedureCall = context.state { return left }

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

    mutating func nud(for token: Lexer.Token) throws -> AST.Node {

        switch token {
        case .operator(let symbol):
            guard let nud = Operator.table.first(where: { $0.symbol == symbol })?.nud else {
                throw error(.nonInfixOperator(token))
            }
            return try nud(&self)

        case .identifier(let symbol):
            try consume()
            return AST.Node(.identifier(symbol))

        case .underscore:
            try consume()
            return AST.Node(.dispose)

        case .integer(let literal):
            try consume()
            return AST.Node(.integer(literal))

        case .real(let literal):
            try consume()
            return AST.Node(.real(literal))

        case .string(let literal):
            try consume()
            return AST.Node(.string(literal))

        case .keyword(.true):
            try consume()
            return AST.Node(.boolean(true))

        case .keyword(.false):
            try consume()
            return AST.Node(.boolean(false))

        case .lparen:
            try consume(.lparen)
            let expr = try expression()
            try consume(.rparen)
            return expr

        case .keyword(.if):
            let (_, startLocation) = try consume(.keyword(.if))

            let conditionExpression = try expression()
            let thenExpression = try expression()

            guard case .keyword(.else)? = try lexer.peek()?.kind else {
                return AST.Node(.conditional, children: [conditionExpression, thenExpression], location: startLocation)
            }

            try consume(.keyword(.else))
            let elseExpression = try expression()
            return AST.Node(.conditional, children: [conditionExpression, thenExpression, elseExpression], location: startLocation)

        case .keyword(.for):
            let (_, startLocation) = try consume(.keyword(.for))

            var expressions: [AST.Node] = []
            while try lexer.peek()?.kind != .lparen {
                let expr = try expression()
                expressions.append(expr)
            }

            push(context: .loopBody)
            defer { popContext() }

            let body = try expression()

            expressions.append(body)

            return AST.Node(.loop, children: expressions, location: startLocation)

        case .keyword(.break):
            let (_, startLocation) = try consume(.keyword(.break))

            guard case .loopBody = context.state else {
                throw error(.nonInfixOperator(token), location: startLocation)
            }

            return AST.Node(.break, location: startLocation)

        case .keyword(.continue):
            let (_, startLocation) = try consume(.keyword(.continue))

            guard case .loopBody = context.state else {
                throw error(.keywordNotValid, location: startLocation)
            }

            return AST.Node(.continue, location: startLocation)

        case .keyword(.return):
            let (_, startLocation) = try consume(.keyword(.return))

            // NOTE(vdka): Is it fine if this fails, will it change the parser state?
            if let expr = try? expression() {
                return AST.Node(.return, children: [expr], location: startLocation)
            } else {
                return AST.Node(.return, location: startLocation)
            }

        case .keyword(.defer):
            let (_, startLocation) = try consume(.keyword(.defer))

            let expr = try expression()
            return AST.Node(.defer, children: [expr], location: startLocation)

        case .lbrace:
            let (_, startLocation) = try consume(.lbrace)

            let scope = context.pushNewScope()
            defer {
                context.popCurrentScope()
            }

            let node = AST.Node(.scope(scope))
            while let next = try lexer.peek()?.kind, next != .rbrace {
                let expr = try expression()
                node.add(expr)
            }

            let (_, endLocation) = try consume(.rbrace)

            node.sourceRange = startLocation..<endLocation

            return node

        case .directive(.file):
            let (_, location) = try consume()
            let wrapped = ByteString(location.file)
            return AST.Node(.string(wrapped))

        case .directive(.line):
            let (_, location) = try consume()
            let wrapped = ByteString(location.line.description)
            return AST.Node(.integer(wrapped))

        case .directive(.import):
            return try Parser.parseImportDirective(&self)

        default:
            fatalError()
        }
    }

    mutating func led(for token: Lexer.Token, with lvalue: AST.Node) throws -> AST.Node {

        switch token {
        case .operator(let symbol):
            guard let led = Operator.table.first(where: { $0.symbol == symbol })?.led else {
                throw error(.nonInfixOperator(token))
            }
            return try led(&self, lvalue)

        case .dot:
            let (_, location) = try consume(.dot)

            guard case let (.identifier(member), memberLocation)? = try lexer.peek() else {
                throw error(.expectedMemberName)
            }
            try consume()

            let rvalue = AST.Node(.identifier(member), location: memberLocation)

            return AST.Node(.memberAccess, children: [lvalue, rvalue], location: location)

        case .comma:
            let (_, location) = try consume()
            reportError("Unexpected comma", at: location)
            return AST.Node(.invalid, location: location)

        case .lbrack:
            let (_, startLocation) = try consume(.lbrack)
            let expr = try expression()
            try consume(.rbrack)

            return AST.Node(.subscript, children: [lvalue, expr], location: startLocation)

        case .lparen:

            return try Parser.parseProcedureCall(&self, lvalue)

        case .equals:

            let (_, location) = try consume(.equals)

            let rhs = try expression()

            return AST.Node(.assignment("="), children: [lvalue, rhs], location: location)

        case .colon:

            if case .colon? = try lexer.peek(aheadBy: 1)?.kind {
                return try Parser.parseCompileTimeDeclaration(&self, lvalue)
            } // '::'

            try consume(.colon)

            switch try lexer.peek()?.kind {
            case .equals?:
                // type is infered
                try consume(.equals)
                let rvalues = try parseMultipleExpressions()

                // TODO(vdka): handle mismatched lhs count and rhs count

                let declValue = Declaration.Value(isVar: true, type: nil, values: rvalues)
                return AST.Node(.decl(.value(declValue)))

            default:
                try consume(.colon)

                // NOTE(vdka): For now you can only have a single type on the lhs
                // TODO(vdka): This should have a warning to explain.
                let type = try parseType()
                let rvalues = try parseMultipleExpressions()

                let declValue = Declaration.Value(isVar: true, type: type, values: rvalues)
                return AST.Node(.decl(.value(declValue)))
            }

        default:
            unimplemented()
        }
    }


    // MARK: Sub parsers

    mutating func parseMultipleExpressions() throws -> [AST.Node] {

        let expr = try expression()
        var expressions: [AST.Node] = [expr]

        while case .comma? = try lexer.peek()?.kind {
            try consume(.comma)

            let expr = try expression()
            expressions.append(expr)
        }

        return expressions
    }

    mutating func parseMultipleTypes() throws -> [AST.Node] {

        let type = try parseType()
        var types: [AST.Node] = [type]

        while case .comma? = try lexer.peek()?.kind {
            try consume(.comma)

            let type = try parseType()
            types.append(type)
        }

        return types
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
            throw error(.expected("something TODO ln Parser.swift:324"), location: try lexer.peek()!.location)
        }

        return try lexer.pop()
    }
}
