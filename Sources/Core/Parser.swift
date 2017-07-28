
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

    static let lowestPrecedence  = 0
    static let unaryPrecedence   = 7
    static let highestPrecedence = 8

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
            nodes.append(node)
            consumeComments()
        }
        return nodes
    }

    mutating func parseIdent() -> Ident {

        var name = "_"
        if tok == .ident {
            name = lit
            next()
        } else {
            expect(.ident)
        }

        return Ident(start: pos, name: name)
    }

    mutating func parseIdentList() -> [Ident] {
        var list: [Ident] = [parseIdent()]
        while tok == .comma {
            next()
            list.append(parseIdent())
        }
        return list
    }

    mutating func parseExprList() -> [Expr] {
        var list: [Expr] = [parseExpr()]
        while tok == .comma && tok != .ellipsis {
            next()
            list.append(parseExpr())
        }
        return list
    }

    mutating func parseType() -> Expr {
        return parsePrimaryExpr(forbidCompositeLiterals: true)
    }

    mutating func parseTypeList() -> [Expr] {
        var list: [Expr] = [parseType()]
        while tok == .comma && tok != .ellipsis {
            next()
            list.append(parseType())
        }
        return list
    }

    mutating func parseArrayType() -> Expr {
        let lbrack = eatToken()
        var len: Expr?
        if tok == .ellipsis { // catch invalid use in checker
            len = Ellipsis(start: pos, element: nil)
            next()
        } else if tok != .rbrack {
            len = parseExpr()
        }

        let rbrack = expect(.rbrack)
        let type = parseType()

        return ArrayType(lbrack: lbrack, len: len, rbrack: rbrack, type: type)
    }

    mutating func parseStructFieldDecl() -> Field {
        let names = parseIdentList()
        let colon = expect(.colon)
        let type = parseType()
        expectTerm()
        return Field(names: names, colon: colon, type: type)
    }

    mutating func parseStructType() -> StructType {
        let keyword = eatToken()
        let lbrace = expect(.lbrace)
        var list: [Field] = []
        while tok == .ident {
            list.append(parseStructFieldDecl())
        }
        let rbrace = expect(.rbrace)

        let fields = FieldList(start: lbrace, fields: list, end: rbrace)
        return StructType(keyword: keyword, fields: fields)
    }

    mutating func parseParameter() -> (Parameter, isVariadic: Bool) {

        var idents = parseIdentList()
        expect(.colon)
        if tok == .ellipsis {
            if idents.count > 1 {
                reportExpected(idents[1].start, "single identifier for variadic")
            }
            let ellipsis = eatToken()
            let variadic = Ellipsis(start: ellipsis, element: parseType())
            return (Parameter(type: variadic), true)
        }
        return (Parameter(type: parseType()), false)
    }

    mutating func parseParameterList() -> ParameterList {
        let lparen = eatToken()
        var list: [Parameter] = []
        while tok != .rparen && tok != .eof {
            let (parameter, isVariadic) = parseParameter()
            list.append(parameter)
            if isVariadic {
                break
            }
        }
        let rparen = expect(.rparen)
        return ParameterList(lparen: lparen, list: list, rparen: rparen)
    }

    mutating func parseResultList() -> ResultList {

        if tok == .lparen { // allow named results
            let lparen = eatToken()
            var types: [Expr] = []
            while tok != .rparen && tok != .eof {
                var expr = parseType()
                if tok == .colon {
                    if !(expr is Ident) {
                        reportError("Expected identifier for result label", at: expr.start)
                    }
                    next()
                    expr = parseType()
                }
                types.append(expr)
            }
            let rparen = expect(.rparen)
            return ResultList(lparen: lparen, types: types, rparen: rparen)
        }

        return ResultList(lparen: nil, types: parseTypeList(), rparen: nil)
    }

    mutating func parseFnLit() -> FuncLit {
        let keyword = eatToken()

        let params = parseParameterList()
        expect(.retArrow)
        let results = parseResultList()
        let body = parseBlockStmt()

        return FuncLit(keyword: keyword, params: params, results: results, body: body)
    }

    mutating func parsePointerType() -> PointerType {
        let star = eatToken()
        let type = parseType()
        return PointerType(star: star, type: type)
    }


    // MARK: Blocks

    mutating func parseStmtList() -> [Stmt] {

        var list: [Stmt] = []
        while tok != .case && tok != .rbrace && tok != .eof {
            list.append(parseStmt())
        }
        return list
    }

    mutating func parseBlockStmt() -> Block {
        let lbrace = eatToken()
        let list = parseStmtList()
        let rbrace = expect(.rbrace)

        return Block(lbrace: lbrace, elements: list, rbrace: rbrace)
    }

    mutating func parseOperand() -> Expr {

        switch tok {
        case .ident:
            return parseIdent()

        case .int, .float, .string:
            let x = BasicLit(start: pos, token: tok, value: lit)
            next()
            return x

        case .lparen:
            let lparen = eatToken()
            var x = parseExprList()
            if tok == .ellipsis {
                let ellipsis = eatToken()
                let varaidic = Ellipsis(start: ellipsis, element: parseType())
                x.append(varaidic)
            }
            let rparen = expect(.rparen)
            if x.count == 1 && tok != .retArrow {
                return Paren(lparen: lparen, element: x[0], rparen: rparen)
            }
            expect(.retArrow)
            let results = parseExprList()
            return FuncType(lparen: lparen, params: x, results: results)

        case .fn:
            return parseFnLit()

        case .struct:
            return parseStructType()

        case .union, .enum:
            fatalError("TODO")

        default:
            return parseType()
        }
    }

    mutating func parseSelector(_ rec: Expr) -> Selector {
        next()

        let sel = parseIdent()
        return Selector(rec: rec, sel: sel)
    }

    mutating func parseCallOrConversion(_ fun: Expr) -> Call {
        let lparen = pos
        next()

        var list: [Expr] = []
        while tok != .rparen && tok != .eof {
            list.append(parseExpr())

            if !atComma(in: "argument list", .rparen) {
                break
            }
            next()
        }

        let rparen = expect(.rparen)
        return Call(fun: fun, lparen: lparen, args: list, rparen: rparen)
    }

    mutating func parseValue() -> Expr {
        let op = parseExpr()
        return op
    }

    mutating func parseElement() -> Expr {

        var el = parseValue()
        if tok == .colon {
            let colon = pos
            next()
            el = KeyValue(key: el, colon: colon, value: parseValue())
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

    mutating func parseLiteralValue(_ type: Expr) -> CompositeLit {
        let lbrace = pos
        next()

        var list: [Expr] = []
        if tok != .lbrace {
            list = parseElementList()
        }
        let rbrace = expect(.rbrace)
        return CompositeLit(type: type, lbrace: lbrace, elements: list, rbrace: rbrace)
    }

    mutating func parsePrimaryExpr(forbidCompositeLiterals: Bool = false) -> Expr {

        var operand = parseOperand()

L:
        while true {
            switch tok {
            case .period:
                operand = parseSelector(operand)

            case .lparen:
                operand = parseCallOrConversion(operand)

            case .lbrace where !forbidCompositeLiterals:
                operand = parseLiteralValue(operand)

            default:
                break L
            }
        }

        return operand
    }

    mutating func parseUnaryExpr() -> Expr {
        switch tok {
        case .add, .sub, .not, .xor, .and:
            let (pos, op) = (self.pos, self.tok)
            next()
            let expr = parseUnaryExpr()
            return Unary(start: pos, op: op, element: expr)

        case .mul:
            return parsePointerType()

        default:
            break
        }

        return parsePrimaryExpr()
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

    mutating func parseExpr() -> Expr {
        return parseBinaryExpr(Parser.lowestPrecedence + 1)
    }
}


// MARK: Statements

extension Parser {

    mutating func parseSimpleStmt() -> Stmt {

        let x = parseExprList()

        switch tok {
        case .assign:
            let pos = self.pos
            next()

            let rhs = parseExprList()

            return Assign(lhs: x, equals: pos, rhs: rhs)

        case .assignAdd, .assignSub, .assignMul, .assignQuo, .assignRem,
             .assignAnd, .assignOr, .assignXor, .assignShl, .assignShr:
            let (pos, tok) = (self.pos, self.tok)
            next()

            let rhs = parseExprList()

            if rhs.count > 1 || x.count > 1 {
                reportError("Assignment macros only permit a single values", at: rhs[0].start)
            }

            /// expands assignment macros to their more verbose form (`i += 1` to `i = i + 1`)
            let operation = Binary(lhs: x[0], op: operatorFor(assignMacro: tok), opPos: pos, rhs: rhs[0])
            return Assign(lhs: x, equals: pos, rhs: [operation])

        case .colon: // could be a label or decl
            let colon = eatToken()

            if x.count == 1, let x = x[0] as? Ident, tok == .semicolon, lit == "\n" {
                let stmt = parseStmt()
                return Labeled(label: x, colon: colon, stmt: stmt)
            }

            var names: [Ident] = []
            for expr in x {
                guard let name = expr as? Ident else {
                    reportExpected(expr.start, "identifier")
                    continue
                }
                names.append(name)
            }

            if tok == .assign {
                eatToken()
                let values = parseExprList()
                expectTerm()
                return VariableDecl(names: names, type: nil, values: values)
            } else if tok == .colon {
                eatToken()
                let values = parseExprList()
                expectTerm()
                return ValueDecl(names: names, type: nil, values: values)
            }

            let type = parseType()

            switch tok {
            case .assign:
                eatToken()
                let values = parseExprList()
                expectTerm()
                return VariableDecl(names: names, type: type, values: values)
            case .colon:
                eatToken()
                let values = parseExprList()
                expectTerm()
                return ValueDecl(names: names, type: type, values: values)
            default:
                expectTerm()
                return VariableDecl(names: names, type: type, values: [])
            }

        default:
            break
        }

        if x.count > 1 {
            reportExpected(x[1].start, "1 expression")
            // continue with first expression
        }
        return ExprStmt(expr: x[0])
    }

    mutating func parseReturnStmt() -> Return {
        let keyword = pos
        next()

        var x: [Expr] = []
        if tok != .semicolon && tok != .rbrace {
            x = parseExprList()
        }
        expectTerm()
        return Return(keyword: keyword, results: x)
    }

    mutating func parseBranchStmt() -> Branch {

        let (tok, pos) = (self.tok, self.pos)
        next()

        var label: Ident?
        if tok != .fallthrough && tok == .ident {
            label = parseIdent()
        }
        expectTerm()
        return Branch(token: tok, label: label, start: pos)
    }

    mutating func parseIfStmt() -> If {
        let keyword = pos
        next()

        let cond = parseExpr()
        let body = parseStmt()

        var els_: Stmt?
        if tok == .else {
            next()
            els_ = parseStmt()
        } else {
            expectTerm()
        }
        return If(keyword: keyword, cond: cond, body: body, els: els_)
    }

    mutating func parseCaseClause() -> CaseClause {
        let keyword = pos
        next()

        var match: Expr?
        if tok != .colon {
            match = parseExpr()
        }
        let colon = expect(.colon)
        let body = parseStmtList()
        expectTerm()
        let block = Block(lbrace: colon, elements: body, rbrace: body.last?.end ?? colon)
        return CaseClause(keyword: keyword, match: match, colon: colon, block: block)
    }

    mutating func parseSwitchStmt() -> Switch {
        let keyword = pos
        next()

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
        let body = Block(lbrace: lbrace, elements: list, rbrace: rbrace)
        return Switch(keyword: keyword, match: match, block: body)
    }

    mutating func parseForStmt() -> For {
        let keyword = pos
        next()

        var s1, s2, s3: Stmt?

        if tok != .lbrace {
            if tok != .semicolon {
                s2 = parseSimpleStmt()
            }
        }
        if tok == .semicolon {
            next()
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

        let body = parseBlockStmt()
        expectTerm()

        var cond: Expr?
        if let s2 = s2, !(s2 is ExprStmt) {
            reportExpected(s2.start, "expression")
            cond = BadExpr(start: s2.start, end: s2.end)
        } else if let s2 = s2 as? ExprStmt {
            cond = s2.expr
        }
        return For(keyword: keyword, initializer: s1, cond: cond, post: s3, body: body)
    }

    mutating func parseStmt() -> Stmt {

        var s: Stmt
        switch tok {
        case
            .ident, .int, .float, .string, .fn, .lparen, // operands
            .lbrack, .struct, .union, .enum,             // composite types
            .add, .sub, .mul, .and, .xor, .not:          // unary operators
            s = parseSimpleStmt()
        case .return:
            s = parseReturnStmt()
        case .break, .continue, .goto, .fallthrough:
            s = parseBranchStmt()
        case .lbrace:
            s = parseBlockStmt()
            expectTerm()
        case .if:
            s = parseIfStmt()
        case .switch:
            s = parseSwitchStmt()
        case .for:
            s = parseForStmt()
        case .rbrace:
            // a semicolon may be omitted before a closing '}'
            s = Empty(semicolon: pos, isImplicit: true)
            next()
        default:
            // no statement found
            let pos = self.pos
            reportExpected(pos, "statement")
            syncStmt()
            s = BadStmt(start: pos, end: self.pos)
        }

        return s
    }
}


// MARK: Helpers

extension Parser {

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

    mutating func next() {
        (pos, tok, lit) = scanner.scan()

        while tok == .comment {
            (pos, tok, lit) = scanner.scan()
        }
    }

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

    // syncStmt advances to the next statement after an error
    mutating func syncStmt() {
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
}


// MARK: Errors

extension Parser {

    @discardableResult
    mutating func eatToken() -> Pos {
        let pos = self.pos
        next()
        return pos
    }

    @discardableResult
    mutating func expect(_ expected: Token, line: UInt = #line) -> Pos {
        let pos = self.pos
        if tok != expected {
            reportExpected(pos, "'" + String(describing: expected) + "'", line: line)
        }
        next()
        return pos
    }

    mutating func expectTerm(line: UInt = #line) {
        if tok != .rparen && tok != .rbrace {
            switch tok {
            case .comma:
                // allow a comma instead of a ';' but complain
                reportExpected(pos, "';'", line: line)
                fallthrough
            case .semicolon:
                next()
            default:
                reportExpected(pos, "';'", line: line)
                syncStmt()
            }
        }
    }

    func atComma(in context: String, _ follow: Token, line: UInt = #line) -> Bool {
        if tok == .comma {
            return true
        }
        if tok != follow {
            var msg = "Missing ','"
            if tok == .semicolon && lit == "\n" {
                msg += " before newline"
            }
            reportExpected(pos, msg + " in " + context, line: line)
            return true // _insert_ comma and continue
        }
        return false
    }

    func reportExpected(_ pos: Pos, _ msg: String, line: UInt = #line) {
        reportError("Expected \(msg), found '\(tok)'", at: pos, line: line)
    }

    func reportError(_ message: String, at pos: Pos, line: UInt = #line) {
        file.addError(message, pos, line: line)
    }
}
