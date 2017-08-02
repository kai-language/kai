
struct Parser {

    var file: SourceFile
    var scanner: Scanner

    var pos: Pos
    var tok: Token
    var lit: String

    // Error recovery
    // (used to limit the number of calls to syncXXX functions
    // w/o making scanning progress - avoids potential endless
    // loops across multiple parser functions during error recovery)
    var syncPos: Pos       // last synchronization position
    var syncCnt: Int = 0   // number of calls to syncXXX without progress

    init(file: SourceFile) {
        self.file = file
        self.scanner = Scanner(file: file, errorHandler: { [unowned file] in file.addError($0, $1) })
        (pos, tok, lit) = scanner.scan()

        self.syncPos = pos
    }

    mutating func parseFile() -> [Node] {

        consumeComments()
        var nodes: [Node] = []
        while tok != .eof {
            let node = parseStmt()
            expectTerm()
            nodes.append(node)
            consumeComments()
        }
        return nodes
    }
}


/// - MARK: Lexemes

extension Parser {

    mutating func parseStringLit() -> BasicLit {
        let start = pos
        var val = "_"
        if tok == .string {
            val = lit
            next()
        } else {
            reportExpected("string literal", at: pos)
        }
        return BasicLit(start: start, token: .string, value: val)
    }

    mutating func parseIdent() -> Ident {
        var name = "_"
        if tok == .ident {
            name = lit
            next()
        } else {
            reportExpected("ident", at: pos)
        }
        return Ident(start: pos, name: name)
    }
}


// - MARK: Common Constructs

extension Parser {

    mutating func parseIdentList() -> [Ident] {
        var list = [parseIdent()]
        while tok == .comma {
            next()
            list.append(parseIdent())
        }
        return list
    }

    mutating func parseExprList() -> [Expr] {
        var list = [parseExpr()]
        while tok == .comma {
            eatToken()
            list.append(parseExpr())
        }
        return list
    }

    mutating func parseTypeList(allowPolyType: Bool = false) -> [Expr] {
        var list = [parseType(allowPolyType: allowPolyType)]
        while tok == .comma {
            eatToken()
            list.append(parseType(allowPolyType: allowPolyType))
        }
        return list
    }

    mutating func parseStmtList() -> [Stmt] {
        var list = [parseStmt()]
        expectTerm()
        while tok != .case && tok != .rbrace && tok != .eof {
            list.append(parseStmt())
            expectTerm()
        }
        return list
    }

    mutating func parseDeclList(foreign: Bool) -> [Decl] {
        var list = [parseDecl(foreign: foreign)]
        expectTerm()
        while tok != .case && tok != .rbrace && tok != .eof {
            list.append(parseDecl(foreign: foreign))
            expectTerm()
        }
        return list
    }

    mutating func parseBlock() -> Block {
        let lbrace = eatToken()
        let stmts = parseStmtList()
        let rbrace = expect(.rbrace)
        return Block(lbrace: lbrace, stmts: stmts, rbrace: rbrace)
    }
}

// - MARK: Expressions

extension Parser {

    mutating func parseExpr() -> Expr {
        return parseBinaryExpr(Parser.lowestPrecedence + 1)
    }

    mutating func parseUnaryExpr() -> Expr {
        switch tok {
        case .add, .sub, .not, .xor, .and:
            let op = tok
            let pos = eatToken()
            let expr = parseUnaryExpr()
            return Unary(start: pos, op: op, element: expr)
        case .mul:
            let star = eatToken()
            return PointerType(star: star, type: parseType())
        default:
            return parsePrimaryExpr()
        }
    }

    mutating func parseBinaryExpr(_ prec1: Int) -> Expr {

        var lhs = parseUnaryExpr()

        while true {
            let op = tok
            let pos = self.pos
            let oprec = tokenPrecedence()
            if oprec < prec1 {
                return lhs
            }
            next()
            let rhs = parseBinaryExpr(oprec + 1)
            lhs = Binary(lhs: lhs, op: op, opPos: pos, rhs: rhs)
        }
    }

    mutating func parseTernaryExpr(_ cond: Expr) -> Expr {
        let qmark = eatToken()
        var then: Expr?
        if tok != .colon {
            then = parseExpr()
        }
        let colon = expect(.colon)
        let els = parseExpr()
        return Ternary(cond: cond, qmark: qmark, then: then, colon: colon, els: els)
    }

    mutating func parsePrimaryExpr() -> Expr {

        var x = parseOperand()

        while true {
            switch tok {
            case .question:
                x = parseTernaryExpr(x)
            case .period:
                eatToken()
                x = Selector(rec: x, sel: parseIdent())
            case .lparen:
                let lparen = eatToken()
                let args = parseExprList()
                let rparen = expect(.rparen)
                x = Call(fun: x, lparen: lparen, args: args, rparen: rparen)
            default:
                return x
            }
        }
    }

    mutating func parseOperand() -> Expr {
        switch tok {
        case .ident:
            return parseIdent()
        case .int, .string, .float:
            let val = BasicLit(start: pos, token: tok, value: lit)
            next()
            return val
        case .fn:
            return parseFuncLit()
        case .lparen:
            let lparen = eatToken()
            let expr = parseExpr()
            let rparen = expect(.rparen)
            return Paren(lparen: lparen, element: expr, rparen: rparen)
        default:
            let type = parseType()
            // TODO: Make lexer auto insert semicolon before '{' when it sees `for` `switch` etc...
            if tok == .lbrace {
                return parseCompositeLiteralBody(type)
            }
            return type
        }
    }
}


// - MARK: Type

extension Parser {

    mutating func parseType(allowPolyType: Bool = false) -> Expr {
        switch tok {
        case .ident:
            return parseIdent()
        case .lbrack:
            let lbrack = eatToken()
            let length = parseExpr()
            let rbrack = expect(.rbrack)
            let type = parseType()
            return ArrayType(lbrack: lbrack, length: length, rbrack: rbrack, type: type)
        case .mul:
            let star = eatToken()
            let type = parseType()
            return PointerType(star: star, type: type)
        case .lparen:
            return parseFuncType()
        case .dollar:
            let dollar = eatToken()
            let type = parseType(allowPolyType: false)
            return PolyType(dollar: dollar, type: type)
        default:
            // we have an error
            let start = pos
            reportExpected("operand", at: start)
            syncStmt()
            return BadExpr(start: start, end: pos)
        }
    }

    mutating func parseFuncType() -> Expr {
        let lparen = eatToken()
        let params = parseParameterTypeList()
        expect(.rparen)
        expect(.retArrow)
        let results = parseTypeList(allowPolyType: true)
        return FuncType(lparen: lparen, params: params, results: results)
    }

    mutating func parseParameterTypeList() -> [Expr] {
        if tok == .ellipsis {
            let ellipsis = eatToken()
            return [VariadicType(ellipsis: ellipsis, type: parseType(allowPolyType: true))]
        }
        var list = [parseType(allowPolyType: true)]
        while tok == .comma {
            next()
            if tok == .ellipsis {
                let ellipsis = eatToken()
                let variadicType = VariadicType(ellipsis: ellipsis, type: parseType(allowPolyType: true))
                list.append(variadicType)
                return list
            }
            list.append(parseType(allowPolyType: true))
        }
        return list
    }

    mutating func parseTypeOrPolyType() -> Expr {
        if tok == .dollar {
            let dollar = eatToken()
            return PolyType(dollar: dollar, type: parseType())
        }
        return parseType()
    }

    mutating func parseStructType() -> Expr {
        let keyword = eatToken()
        let lbrace = expect(.lbrace)
        let fields = parseStructFieldList()
        let rbrace = expect(.rbrace)
        return StructType(keyword: keyword, lbrace: lbrace, fields: fields, rbrace: rbrace)
    }

    mutating func parseStructFieldList() -> [StructField] {
        var list = [parseStructField()]
        while tok == .comma {
            next()
            list.append(parseStructField())
        }
        return list
    }

    mutating func parseStructField() -> StructField {
        let names = parseIdentList()
        let colon = expect(.colon)
        let type = parseType()
        return StructField(names: names, colon: colon, type: type)
    }


    // MARK: Function Literals

    mutating func parseFuncLit() -> FuncLit {
        let keyword = eatToken()
        let signature = parseSignature()
        expect(.retArrow)
        let results = parseResultList()
        let body = parseBlock()
        return FuncLit(keyword: keyword, params: signature, results: results, body: body)
    }

    mutating func parseSignature() -> ParameterList {
        let lparen = expect(.lparen)
        var list: [Parameter] = []
        if tok != .rparen {
            list = parseParameterList()
        }
        let rparen = expect(.rparen)
        return ParameterList(lparen: lparen, list: list, rparen: rparen)
    }

    mutating func parseParameterList() -> [Parameter] {
        var list = [parseParameter()]
        while tok == .comma {
            next()
            list.append(parseParameter())
        }
        return list
    }

    mutating func parseParameter() -> Parameter {
        let names = parseParameterNames()
        // TODO: Explicit Poly Parameters
        expect(.colon)
        let type = parseType()
        return Parameter(names: names, type: type)
    }

    mutating func parseParameterNames() -> [(poly: Bool, Ident)] {
        var poly = tok == .dollar
        if poly {
            eatToken()
        }
        var list = [(poly, parseIdent())]
        while tok == .comma {
            next()
            poly = tok == .dollar
            if poly {
                eatToken()
            }
            list.append((poly, parseIdent()))
        }
        return list
    }

    mutating func parseResultList() -> ResultList {
        var lparen: Pos?
        var resultTypes: [Expr]
        var rparen: Pos?
        if tok == .lparen {
            lparen = eatToken()
            resultTypes = parseLabeledResultList()
            rparen = expect(.rparen)
        } else {
            resultTypes = parseTypeList(allowPolyType: true)
        }
        return ResultList(lparen: lparen, types: resultTypes, rparen: rparen)
    }

    mutating func parseLabeledResultList() -> [Expr] {
        var list = [parseResult()]
        while tok == .comma {
            next()
            list.append(parseResult())
        }
        return list
    }

    mutating func parseResult() -> Expr {
        var type = parseTypeOrPolyType()
        if tok == .colon {
            if !(type is Ident) {
                reportExpected("identifier", at: type.start)
            }
            eatToken()
            type = parseTypeOrPolyType()
        }
        return type
    }


    // MARK: - Composite Literals

    mutating func parseElement() -> Expr {
        var el = parseExpr()
        if tok == .colon {
            let colon = eatToken()
            el = KeyValue(key: el, colon: colon, value: parseExpr())
        }
        return el
    }

    mutating func parseElementList() -> [Expr] {
        var list: [Expr] = []
        while tok != .rbrace && tok != .eof {
            list.append(parseElement())
            if !atComma(in: "composite literal", .rbrace) {
                break
            }
            next()
        }
        return list
    }

    mutating func parseCompositeLiteralBody(_ type: Expr) -> CompositeLit {
        let lbrace = eatToken()
        var list: [Expr] = []
        if tok != .lbrace {
            list = parseElementList()
        }
        let rbrace = expect(.rbrace)
        return CompositeLit(type: type, lbrace: lbrace, elements: list, rbrace: rbrace)
    }
}


// - MARK: Declarations And Statements

extension Parser {

    mutating func parseStmt() -> Stmt {
        switch tok {
        case .ident, .int, .float, .string, .fn, .lparen, // operands
             .lbrack, .struct, .union, .enum,             // composite types
             .add, .sub, .mul, .and, .xor, .not:          // unary operators
             return parseSimpleStmt()
        case .break, .continue, .goto, .fallthrough:
            return parseBranch()
        case .return:
            return parseReturn()
        case .lbrace:
            let block = parseBlock()
            return block
        case .if:
            return parseIfStmt()
        case .switch:
            return parseSwitchStmt()
        case .for:
            return parseForStmt()
        case .directive:
            return parseDirective()
        case .rbrace:
            return Empty(semicolon: pos, isImplicit: true)
        default:
            let start = pos
            reportExpected("statement", at: start)
            syncStmt()
            return BadStmt(start: start, end: pos)
        }
    }

    mutating func parseSimpleStmt() -> Stmt {

        let x = parseExprList()

        switch tok {
        case .assign:
            let equals = eatToken()
            let rhs = parseExprList()
            return Assign(lhs: x, equals: equals, rhs: rhs)
        case .assignAdd, .assignSub, .assignMul, .assignQuo, .assignRem,
             .assignAnd, .assignOr, .assignXor, .assignShl, .assignShr:
            let pos = self.pos
            let tok = self.tok
            eatToken()
            let rhs = parseExprList()
            if rhs.count > 1 || x.count > 1 {
                reportError("Assignment macros only permit a single values", at: rhs[0].start)
            }
            let operation = Binary(lhs: x[0], op: operatorFor(assignMacro: tok), opPos: pos, rhs: rhs[0])
            return Assign(lhs: x, equals: pos, rhs: [operation])
        case .colon: // could be label or decl
            let colon = eatToken()
            if x.count == 1, let x = x[0] as? Ident, tok == .semicolon, lit == "\n" {
                return Label(label: x, colon: colon)
            }
            var names: [Ident] = []
            for expr in x {
                guard let name = expr as? Ident else {
                    reportExpected("identifier", at: expr.start)
                    continue
                }
                names.append(name)
            }
            if tok == .assign {
                eatToken()
                let values = parseExprList()
                return VariableDecl(names: names, type: nil, values: values, callconv: nil, linkname: nil)
            } else if tok == .colon {
                eatToken()
                let values = parseExprList()
                return ValueDecl(names: names, type: nil, values: values, callconv: nil, linkname: nil)
            }
            let type = parseType()
            switch tok {
            case .assign:
                eatToken()
                let values = parseExprList()
                return VariableDecl(names: names, type: type, values: values, callconv: nil, linkname: nil)
            case .colon:
                eatToken()
                let values = parseExprList()
                return ValueDecl(names: names, type: type, values: values, callconv: nil, linkname: nil)
            default:
                return VariableDecl(names: names, type: type, values: [], callconv: nil, linkname: nil)
            }
        default:
            break
        }

        if x.count > 1 {
            reportExpected("1 expression", at: x[1].start)
            // continue with first expression
        }

        return ExprStmt(expr: x[0])
    }

    mutating func parseReturn() -> Return {
        let keyword = eatToken()
        var x: [Expr] = []
        if tok != .semicolon && tok != .rbrace {
            x = parseExprList()
        }
        expectTerm()
        return Return(keyword: keyword, results: x)
    }

    mutating func parseBranch() -> Branch {
        let token = tok
        let start = eatToken()
        var label: Ident?
        if tok != .fallthrough && tok == .ident {
            label = parseIdent()
        }
        expectTerm()
        return Branch(token: token, label: label, start: start)
    }

    mutating func parseIfStmt() -> If {
        let keyword = eatToken()
        let cond = parseExpr()
        // TODO: Disambiguate composite lit
        let body = parseStmt()
        var els_: Stmt?
        if tok == .else {
            eatToken()
            els_ = parseStmt()
        } else {
            expectTerm()
        }
        return If(keyword: keyword, cond: cond, body: body, els: els_)
    }

    mutating func parseSwitchStmt() -> Switch {
        let keyword = eatToken()
        var match: Expr?
        if tok != .lbrace {
            match = parseExpr()
        }
        let lbrace = expect(.lbrace)
        var list: [Stmt] = []
        while tok == .case {
            list.append(parseCaseClause())
        }
        let rbrace = expect(.rbrace)
        expectTerm()
        let body = Block(lbrace: lbrace, stmts: list, rbrace: rbrace)
        return Switch(keyword: keyword, match: match, block: body)
    }

    mutating func parseCaseClause() -> CaseClause {
        let keyword = eatToken()
        var match: Expr?
        if tok != .colon {
            match = parseExpr()
        }
        let colon = expect(.colon)
        let body = parseStmtList()
        expectTerm()
        let block = Block(lbrace: colon, stmts: body, rbrace: body.last?.end ?? colon)
        return CaseClause(keyword: keyword, match: match, colon: colon, block: block)
    }

    mutating func parseForStmt() -> For {
        let keyword = eatToken()
        var s1, s2, s3: Stmt?
        if tok != .lbrace && tok != .semicolon {
            s2 = parseSimpleStmt()
        }
        if tok == .semicolon {
            eatToken()
            s1 = s2
            s2 = nil
            if tok != .semicolon {
                s2 = parseSimpleStmt()
            }
            expectTerm()
            if tok != .lbrace {
                s3 = parseSimpleStmt()
            }
        }
        expectTerm() // Scanner inserts a
        let body = parseBlock()
        expectTerm()
        var cond: Expr?
        if let s2 = s2 as? ExprStmt {
            cond = s2.expr
        } else if let s2 = s2 {
            reportExpected("expression", at: s2.start)
            cond = BadExpr(start: s2.start, end: s2.end)
        }
        return For(keyword: keyword, initializer: s1, cond: cond, post: s3, body: body)
    }
}


// - MARK: Directives

extension Parser {

    mutating func parseDirective(foreign: Bool = false) -> Stmt {
        let name = lit
        let directive = eatToken()
        switch name {
        case "import":
            let path = parseExpr()
            var alias: Ident?
            var importSymbolsIntoScope = false
            if tok == .ident {
                alias = parseIdent()
            } else if tok == .period {
                eatToken()
                importSymbolsIntoScope = true
            } else if tok != .semicolon {
                reportError("Expected identifier to bind imported or terminator", at: pos)
            }

            let i = Import(directive: directive, path: path, alias: alias, importSymbolsIntoScope: importSymbolsIntoScope, file: file)
            i.file = file.add(import: i, importedFrom: file)
            return i
        case "library":
            let path = parseExpr()
            var alias: Ident?
            if tok == .ident {
                alias = parseIdent()
            }
            return Library(directive: directive, path: path, alias: alias)
        case "foreign":
            let library = parseIdent()
            switch tok {
            case .lbrace:
                let block = parseDeclBlock(foreign: true)
                return Foreign(directive: directive, library: library, decl: block, linkname: nil, callconv: nil)
            default:
                let decl = parseDecl(foreign: true)
                return Foreign(directive: directive, library: library, decl: decl, linkname: nil, callconv: nil)
            }
        case "linkname":
            let linkname = parseStringLit()

            var x: Stmt
            if tok == .directive {
                 x = parseDirective(foreign: foreign)
            } else {
                x = parseDecl(foreign: foreign)
            }
            guard let decl = x as? LinknameApplicable else {
                reportExpected("declaration", at: x.start)
                break
            }
            decl.linkname = linkname.value
            return decl
        case "callconv":
            let conv = parseStringLit()
            var x: Stmt
            if tok == .directive {
                x = parseDirective(foreign: foreign)
            } else if tok == .lbrace {
                x = parseDeclBlock(foreign: foreign)
            } else {
                x = parseDecl(foreign: foreign)
            }
            switch x {
            case let block as DeclBlock:
                // TODO: Take normal block and convert to declblock
                block.callconv = conv.value
            case let decl as CallConvApplicable:
                decl.callconv = conv.value
            default:
                reportExpected("individual or block of declarations", at: x.start)
                return BadStmt(start: directive, end: x.end)
            }
            return x
        case "cvargs":
            reportError("cvargs directive is only valid before a vargs parameter", at: directive)
        default:
            reportError("Unknown directive '\(name)'", at: directive)
        }
        return BadStmt(start: directive, end: pos)
    }

    mutating func parseDeclBlock(foreign: Bool) -> DeclBlock {
        let lbrace = eatToken()
        let decls = parseDeclList(foreign: foreign)
        let rbrace = expect(.rbrace)
        return DeclBlock(lbrace: lbrace, decls: decls, rbrace: rbrace, callconv: nil)
    }

    mutating func parseDecl(foreign: Bool) -> Decl {
        if tok == .directive {
            let x = parseDirective(foreign: foreign)
            guard let decl = x as? Decl else {
                reportExpected("declaration", at: x.start)
                return BadDecl(start: x.start, end: x.end)
            }
            return decl
        }
        let name = parseIdent()
        expect(.colon)
        if tok == .assign {
            reportExpected("type", at: pos)
            file.attachNote("Variable declarations in declaration blocks must not have a value")
            file.attachNote("Perhaps you meant to make a ValueDeclaration using ':' instead of '='") 
            eatToken()
            let end = pos
            syncStmt()
            return BadDecl(start: name.start, end: end)
        } else if tok == .colon {
            eatToken()
            let type = parseType()
            return ValueDecl(names: [name], type: type, values: [], callconv: nil, linkname: nil)
        } else {
            let type = parseType()
            return VariableDecl(names: [name], type: type, values: [], callconv: nil, linkname: nil)
        }
    }

    mutating func parseForeignFuncLit() -> ForeignFuncLit {
        let keyword = eatToken()
        let params = parseSignature()
        expect(.retArrow)
        let results = parseResultList()
        if tok == .lbrace {
            reportError("Foreign function declarations need not have a body", at: pos)
        }
        return ForeignFuncLit(keyword: keyword, params: params, results: results)
    }
}


// - MARK: Helpers

extension Parser {

    @discardableResult
    mutating func consumeComments() -> [Comment?] {
        var list: [Comment?] = []
        while tok == .comment {
            if tok == .comment {
                let comment = Comment(slash: pos, text: lit)
                list.append(comment)
            } else {
                list.append(nil) // 1 nil for all sequential newlines
            }
            next()
        }
        return list
    }

    static let lowestPrecedence  = 0
    static let unaryPrecedence   = 7
    static let highestPrecedence = 8

    mutating func next() {
        (pos, tok, lit) = scanner.scan()

        while tok == .comment {
            (pos, tok, lit) = scanner.scan()
        }
    }

    func operatorFor(assignMacro: Token) -> Token {
        assert(Token(rawValue: Token.assignAdd.rawValue - 10)! == .add)

        return Token(rawValue: Token.assignAdd.rawValue - 10)!
    }

    func tokenPrecedence() -> Int {
        switch tok {
        case .lor:
            return 1
        case .land:
            return 2
        case .eql, .neq, .lss, .leq, .gtr, .geq:
            return 3
        case .add, .sub, .or, .xor:
            return 4
        case .mul, .quo, .rem, .shl, .shr, .and:
            return 5
        default:
            return Parser.lowestPrecedence
        }
    }
}


// - MARK: Errors

extension Parser {

    // syncStmt advances to the next statement after an error
    mutating func syncStmt() {
        var prevPos = pos
        while true {
            switch tok {
            case .break, .continue, .defer, .fallthrough, .for, .goto, .if, .return, .switch:
                // Return only if parser made some progress since last
                // sync or if it has not reached 10 sync calls without
                // progress. Otherwise consume at least one token to
                // avoid an endless parser loop (it is possible that
                // both parseOperand and parseStmt call syncStmt and
                // correctly do not advance, thus the need for the
                // invocation limit p.syncCnt).
                if pos == syncPos && syncCnt < 10 {
                    syncCnt += 1
                    return
                }
                if pos > syncPos {
                    syncPos = pos
                    syncCnt = 0
                }
            case .eof:
                return
            default:
                break
            }
            next()
        }
    }

    @discardableResult
    mutating func eatToken() -> Pos {
        let pos = self.pos
        next()
        return pos
    }

    @discardableResult
    mutating func expect(_ expected: Token, function: StaticString = #function, line: UInt = #line) -> Pos {
        let pos = self.pos
        if tok != expected {
            reportExpected("'" + String(describing: expected) + "'", at: pos, function: function, line: line)
        }
        next() // make progress
        return pos
    }

    mutating func expectTerm(function: StaticString = #function, line: UInt = #line) {
        if tok != .rparen && tok != .rbrace {
            switch tok {
            case .comma:
                // allow a comma instead of a ';' but complain
                reportExpected("';'", at: pos, function: function, line: line)
                fallthrough
            case .semicolon:
                next()
            default:
                reportExpected("';'", at: pos, function: function, line: line)
                syncStmt()
            }
        }
    }

    func atComma(in context: String, _ follow: Token, function: StaticString = #function, line: UInt = #line) -> Bool {
        if tok == .comma {
            return true
        }
        if tok != follow {
            var msg = "Missing ','"
            if tok == .semicolon && lit == "\n" {
                msg += " before newline"
            }
            reportExpected(msg + " in " + context, at: pos, function: function, line: line)
            return true // _insert_ comma and continue
        }
        return false
    }

    func reportExpected(_ msg: String, at pos: Pos, function: StaticString = #function, line: UInt = #line) {
        reportError("Expected \(msg), found '\(tok)'", at: pos, function: function, line: line)
    }

    func reportError(_ message: String, at pos: Pos, function: StaticString = #function, line: UInt = #line) {
        file.addError(message, pos)
        #if DEBUG
            file.attachNote("In \(file.stage), \(function), line \(line)")
            file.attachNote("At an offset of \(file.offset(pos: pos)) in the file")
        #endif
    }
}

