
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

    mutating func parseFile() -> [TopLevelStmt] {

        consumeComments()
        var nodes: [TopLevelStmt] = []
        while tok != .eof {
            let node = parseTopLevelStmt()
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
        return BasicLit(start: start, token: .string, text: val, type: nil, constant: unquote(val))
    }

    mutating func parseIdent() -> Ident {
        var name = "_"
        if tok == .ident {
            name = lit
            next()
        } else {
            reportExpected("ident", at: pos)
        }
        return Ident(start: pos, name: name, entity: nil, type: nil, cast: nil, constant: nil)
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
            next()
            list.append(parseExpr())
        }
        return list
    }

    mutating func parseTypeList(allowPolyType: Bool = false) -> [Expr] {
        var list = [parseType(allowPolyType: allowPolyType)]
        while tok == .comma {
            next()
            list.append(parseType(allowPolyType: allowPolyType))
        }
        return list
    }

    mutating func parseStmtList() -> [Stmt] {
        var list = [parseStmt()]
        while tok != .case && tok != .rbrace && tok != .eof {
            list.append(parseStmt())
        }
        return list
    }

    mutating func parseDeclList(foreign: Bool) -> [Decl] {
        var list = [parseDeclForBlock(foreign: foreign)]
        while tok != .case && tok != .rbrace && tok != .eof {
            list.append(parseDeclForBlock(foreign: foreign))
        }
        return list
    }

    /// - Note: Does not consume semicolon
    mutating func parseBlock() -> Block {
        let lbrace = eatToken()
        var stmts: [Stmt] = []
        if tok != .rbrace {
            stmts = parseStmtList()
        }
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
        case .add, .sub, .not, .xor, .and, .lss:
            let op = tok
            let pos = eatToken()
            let expr = parseUnaryExpr()
            return Unary(start: pos, op: op, element: expr, type: nil)
        case .mul:
            let star = eatToken()
            return PointerType(star: star, explicitType: parseType(), type: nil)
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
            lhs = Binary(lhs: lhs, op: op, opPos: pos, rhs: rhs, type: nil, irOp: nil, irLCast: nil, irRCast: nil, isPointerArithmetic: nil)
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
        return Ternary(cond: cond, qmark: qmark, then: then, colon: colon, els: els, type: nil)
    }

    mutating func parsePrimaryExpr() -> Expr {

        var x = parseOperand()

        while true {
            switch tok {
            case .question:
                x = parseTernaryExpr(x)
            case .period:
                next()
                x = Selector(rec: x, sel: parseIdent(), checked: nil, type: nil, cast: nil, constant: nil)
            case .lbrack:
                next()
                let index = parseExpr()
                expect(.rbrack)
                x = Subscript(rec: x, index: index, type: nil, checked: nil)
            case .lparen:
                let lparen = eatToken()
                var args: [Expr] = []
                if tok != .rparen {
                    args = parseExprList()
                }
                let rparen = expect(.rparen)
                x = Call(fun: x, lparen: lparen, args: args, rparen: rparen, type: nil, checked: nil)
            case .lbrace:
                if x is FuncType {
                    reportError("Unexpected '{' after function type", at: x.end)
                    file.attachNote("Did you mean to declare a function? Add 'fn'")
                    return x
                }

                return parseCompositeLiteralBody(x)
            default:
                return x
            }
        }
    }

    mutating func parseOperand() -> Expr {
        switch tok {
        case .nil:
            let start = eatToken()
            return Nil(start: start, type: nil)
        case .ident:
            return parseIdent()
        case .string:
            let val = BasicLit(start: pos, token: tok, text: lit, type: nil, constant: unquote(lit))
            next()
            return val
        case .int, .float:
            let val = BasicLit(start: pos, token: tok, text: lit, type: nil, constant: nil)
            next()
            return val
        case .fn:
            return parseFuncLit()
        case .cast, .bitcast:
            return parseCast()
        case .autocast:
            return parseAutocast()
        case .lparen:
            return parseFuncType(allowParenthesizedExpr: true)
        case .directive:
            let name = lit
            let directive = eatToken()
            switch name {
            case "asm":
                fatalError("Inline assembly is not yet supported")
            default:
                reportError("Unknown directive '\(name)'", at: directive)
                return BadExpr(start: directive, end: directive)
            }
        default:
            return parseType()
        }
    }

    mutating func parseCast() -> Cast {
        let kind = tok
        let keyword = eatToken()
        expect(.lparen)
        let explicitType = parseType()
        expect(.rparen)
        let expr = parseExpr()
        return Cast(keyword: keyword, kind: kind, explicitType: explicitType, expr: expr, type: nil, op: nil)
    }

    mutating func parseAutocast() -> Autocast {
        let keyword = eatToken()
        let expr = parseExpr()
        return Autocast(keyword: keyword, expr: expr, type: nil, op: nil)
    }

    mutating func parseUsingStmt() -> Using {
        let keyword = eatToken()
        let expr = parseExpr()
        allowTerminator()
        return Using(keyword: keyword, expr: expr)
    }
}


// - MARK: Type

extension Parser {

    mutating func parseType(allowPolyType: Bool = false, allowVariadic: Bool = false) -> Expr {
        switch tok {
        case .ident:
            let x = parseIdent()
            if tok == .period {
                next()
                return Selector(rec: x, sel: parseIdent(), checked: nil, type: nil, cast: nil, constant: nil)
            }
            return x
        case .lbrack:
            let lbrack = eatToken()
            var isVector = false

            if tok == .ident && lit == "vec" {
                next()
                isVector = true
            }

            let length: Expr?
            if tok != .ellipsis {
                length = parseExpr()
            } else {
                length = nil
                next()
            }

            let rbrack = expect(.rbrack)
            let type = parseType()

            if let length = length {
                if isVector {
                    return VectorType(lbrack: lbrack, size: length, rbrack: rbrack, explicitType: type, type: nil)
                }

                return ArrayType(lbrack: lbrack, length: length, rbrack: rbrack, explicitType: type, type: nil)
            } else {
                return DynamicArrayType(
                    lbrack: lbrack, rbrack: rbrack, explicitType: type, type: nil)
            }
        case .mul:
            let star = eatToken()
            let type = parseType()
            return PointerType(star: star, explicitType: type, type: nil)
        case .lparen:
            return parseFuncType(allowParenthesizedExpr: false)
        case .dollar:
            let dollar = eatToken()
            let type = parseType(allowPolyType: false)
            return PolyType(dollar: dollar, explicitType: type, type: nil)
        case .struct:
            return parseStructType()
        case .enum:
            return parseEnumType()
        case .ellipsis where allowVariadic:
            let ellipsis = eatToken()
            let variadic = VariadicType(ellipsis: ellipsis, explicitType: parseType(allowPolyType: true), isCvargs: false, type: nil)
            return variadic
        case .directive where lit == "cvargs" && allowVariadic:
            next()
            let ellipsis = expect(.ellipsis)
            let variadic = VariadicType(ellipsis: ellipsis, explicitType: parseType(allowPolyType: true), isCvargs: true, type: nil)
            return variadic
        default:
            // we have an error
            let start = pos
            reportExpected("operand", at: start)
            recover()
            return BadExpr(start: start, end: pos)
        }
    }

    mutating func parseFuncType(allowParenthesizedExpr: Bool) -> Expr {
        let lparen = eatToken()
        if tok == .rparen {
            next()
            expect(.retArrow)
            let results = parseResultList()

            return FuncType(lparen: lparen, params: [], results: results.types, flags: .none, type: nil)
        }

        var parametersShouldBeNamed: Bool = false
        var types: [Expr] = []
        let firstExpr = parseExpr()
        if tok == .rparen {
            // covers "(" Expr ")" and "(" Type ")" "->" ResultList
            let rparen = eatToken()
            if tok != .retArrow && allowParenthesizedExpr {
                return Paren(lparen: lparen, element: firstExpr, rparen: rparen)
            }
            expect(.retArrow)
            let results = parseResultList()
            return FuncType(lparen: lparen, params: [firstExpr], results: results.types, flags: .none, type: nil)
        }

        // Determine if FuncType includes named parameters
        if firstExpr is Ident && tok == .comma {
            next()
            let rest = parseExprList()
            if rest.reduce(true, { $0 && $1 is Ident }), tok == .colon {
                next()
                // If all expressions are idents followed by a colon, they are argument labels
                let type = parseType(allowPolyType: true, allowVariadic: false)
                types.append(contentsOf: repeatElement(type, count: rest.count + 1)) // +1 for firstExpr
                parametersShouldBeNamed = true
            } else {
                types.append(firstExpr)
                types.append(contentsOf: rest)
            }
        } else if firstExpr is Ident && tok == .colon {
            next()
            let type = parseType(allowPolyType: true, allowVariadic: true)
            types.append(type)
            parametersShouldBeNamed = true
            if type is VariadicType || tok == .rparen {
                expect(.rparen)
                expect(.retArrow)
                let results = parseResultList()
                return FuncType(lparen: lparen, params: types, results: results.types, flags: .none, type: nil)
            }
        } else {
            types.append(firstExpr)
        }

        while tok == .comma {
            next()
            if parametersShouldBeNamed {
                let idents = parseIdentList()
                expect(.colon)
                let type = parseType(allowPolyType: true, allowVariadic: idents.count == 1)
                types.append(contentsOf: repeatElement(type, count: idents.count))
                if type is VariadicType || tok == .rparen {
                    break
                }
            } else {
                let type = parseType(allowPolyType: true, allowVariadic: true)
                types.append(type)
                if type is VariadicType || tok == .rparen {
                    break
                }
            }
        }
        expect(.rparen)
        expect(.retArrow)
        let results = parseResultList()
        return FuncType(lparen: lparen, params: types, results: results.types, flags: .none, type: nil)
    }

    mutating func parseParameterTypeList() -> [Expr] {
        if tok == .ellipsis {
            let ellipsis = eatToken()
            let variadic = VariadicType(ellipsis: ellipsis, explicitType: parseType(allowPolyType: true), isCvargs: false, type: nil)
            return [variadic]
        } else if tok == .directive && lit == "cvargs" {
            next()
            let ellipsis = expect(.ellipsis)
            let variadic = VariadicType(ellipsis: ellipsis, explicitType: parseType(allowPolyType: true), isCvargs: true, type: nil)
            return [variadic]
        }
        var list = [parseType(allowPolyType: true)]
        while tok == .comma {
            next()
            if tok == .ellipsis {
                let ellipsis = eatToken()
                let variadicType = VariadicType(ellipsis: ellipsis, explicitType: parseType(allowPolyType: true), isCvargs: false, type: nil)
                list.append(variadicType)
                return list
            } else if tok == .directive && lit == "cvargs" {
                next()
                let ellipsis = expect(.ellipsis)
                let variadic = VariadicType(ellipsis: ellipsis, explicitType: parseType(allowPolyType: true), isCvargs: true, type: nil)
                return [variadic]
            }
            list.append(parseType(allowPolyType: true))
        }
        return list
    }

    mutating func parseStructType() -> Expr {
        let keyword = eatToken()

        if tok == .lparen {
            return parsePolymorphicStructType()
        }

        let lbrace = expect(.lbrace)
        var fields: [StructField] = []
        if tok != .rbrace {
            fields = parseStructFieldList()
        }
        if tok == .semicolon {
            next()
        }
        let rbrace = expect(.rbrace)
        return StructType(keyword: keyword, lbrace: lbrace, fields: fields, rbrace: rbrace, type: nil, checked: nil)
    }

    mutating func parseEnumType() -> Expr {
        let keyword = eatToken()
        var explicitType: Expr?
        if tok == .lparen {
            next()
            explicitType = parseType()
            expect(.rparen)
        }
        expect(.lbrace)

        var cases: [EnumCase] = []
        if tok != .rbrace {
            cases = parseEnumCaseList()
        }

        if tok == .semicolon {
            next()
        }

        let rbrace = expect(.rbrace)
        return EnumType(keyword: keyword, explicitType: explicitType, cases: cases, rbrace: rbrace, type: nil)
    }

    mutating func parsePolymorphicStructType() -> Expr {
        let params = parsePolyStructSignature()
        let lbrace = expect(.lbrace)
        var fields: [StructField] = []
        if tok != .rbrace {
            fields = parseStructFieldList()
        }
        if tok == .semicolon {
            next()
        }
        let rbrace = expect(.rbrace)
        return PolyStructType(lbrace: lbrace, polyTypes: params, fields: fields, rbrace: rbrace, type: nil)
    }

    mutating func parsePolyStructSignature() ->  PolyParameterList {
        let lparen = expect(.lparen)
        var list: [PolyType] = []
        if tok != .rparen {
            list = parsePolyStructParameterList()
        }
        let rparen = expect(.rparen)
        return PolyParameterList(lparen: lparen, list: list, rparen: rparen)
    }

    mutating func parsePolyStructParameterList() -> [PolyType] {
        var list: [PolyType] = [parsePolyType()]
        while tok == .comma {
            next()
            list.append(parsePolyType())
        }
        return list
    }

    mutating func parsePolyType() -> PolyType {
        let dollar = expect(.dollar)
        let explicitType = parseIdent()
        return PolyType(dollar: dollar, explicitType: explicitType, type: nil)
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
        return StructField(names: names, colon: colon, explicitType: type, type: nil)
    }

    mutating func parseEnumCaseList() -> [EnumCase] {
        var list: [EnumCase] = []
        while tok != .rbrace && tok != .eof {
            list.append(parseEnumCase())
            if !atComma(in: "enum", .rbrace) {
                break
            }
            next()
        }
        return list
    }

    mutating func parseEnumCase() -> EnumCase {
        let name = parseIdent()
        var value: Expr?
        if tok == .assign {
            next()
            value = parseExpr()
        }
        return EnumCase(name: name, value: value)
    }


    // MARK: Function Literals

    mutating func parseFuncLit() -> Expr {
        let keyword = eatToken()
        let signature = parseSignature()
        expect(.retArrow)
        let results = parseResultList()
        let body = parseBlock()
        return FuncLit(keyword: keyword, params: signature, results: results, body: body, flags: .none, type: nil, checked: nil)
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
        var list = parseParameters()
        while tok == .comma {
            next()
            list.append(contentsOf: parseParameters())
        }
        return list
    }

    mutating func parseParameters() -> [Parameter] {
        if tok == .dollar {
            let dollar = eatToken()
            let name = parseIdent()
            expect(.colon)
            let type = parseType(allowPolyType: false)
            return [Parameter(dollar: dollar, name: name, explicitType: type, entity: nil)]
        }
        let names = parseIdentList()
        expect(.colon)
        let type = parseType(allowPolyType: true, allowVariadic: true)
        return names.map({ Parameter(dollar: nil, name: $0, explicitType: type, entity: nil) })
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
        var type = parseType(allowPolyType: true)
        if tok == .colon {
            if !(type is Ident) {
                reportExpected("identifier", at: type.start)
            }
            next()
            type = parseType(allowPolyType: true)
        }
        return type
    }


    // MARK: - Composite Literals

    mutating func parseElement() -> KeyValue {
        let el = parseExpr()
        if tok == .colon {
            let colon = eatToken()
            return KeyValue(key: el, colon: colon, value: parseExpr(), type: nil, structField: nil)
        }
        return KeyValue(key: nil, colon: nil, value: el, type: nil, structField: nil)
    }

    mutating func parseElementList() -> [KeyValue] {
        var list: [KeyValue] = []
        while tok != .rbrace && tok != .eof {
            list.append(parseElement())
            if !atComma(in: "composite literal", .rbrace) {
                break
            }
            next()
        }
        return list
    }

    mutating func parseNestedCompositeLiteralBody(_ type: ArrayType) -> CompositeLit {
        let lbrace = eatToken()

        var list: [KeyValue] = []
        while tok != .rbrace && tok != .eof {
            let val = parseCompositeLiteralBody(type.explicitType)
            list.append(KeyValue(key: nil, colon: nil, value: val, type: nil, structField: nil))
            if !atComma(in: "composite literal", .rbrace) {
                break
            }
            next()
        }

        let rbrace = expect(.rbrace)
        return CompositeLit(explicitType: type, lbrace: lbrace, elements: list, rbrace: rbrace, type: nil)
    }

    mutating func parseCompositeLiteralBody(_ type: Expr) -> CompositeLit {
        if let array = type as? ArrayType, array.explicitType is ArrayType {
            return parseNestedCompositeLiteralBody(array)
        }

        let lbrace = eatToken()

        let list: [KeyValue] = parseElementList()
        let rbrace = expect(.rbrace)
        return CompositeLit(explicitType: type, lbrace: lbrace, elements: list, rbrace: rbrace, type: nil)
    }
}


// - MARK: Declarations And Statements

extension Parser {

    mutating func parseTopLevelStmt() -> TopLevelStmt {
        let stmt = parseStmt()
        guard let tlStmt = stmt as? TopLevelStmt else {
            reportError("Expected a top level statement", at: stmt.start)
            return BadStmt(start: stmt.start, end: stmt.end)
        }
        return tlStmt
    }

    mutating func parseStmt() -> Stmt {
        switch tok {
        case .ident, .int, .float, .string, .fn, .lparen, // operands
             .lbrack, .struct, .union, .enum,             // composite types
             .add, .sub, .mul, .and, .xor, .not:          // unary operators
             let s = parseSimpleStmt()
            expectTerm()
            return s
        case .break, .continue, .goto, .fallthrough:
            return parseBranch()
        case .return:
            return parseReturn()
        case .lbrace:
            let block = parseBlock()
            expectTerm()
            return block
        case .if:
            return parseIfStmt()
        case .switch:
            return parseSwitchStmt()
        case .for:
            return parseForStmt()
        case .using:
            return parseUsingStmt()
        case .directive:
            return parseLeadingDirective()
        case .rbrace:
            return Empty(semicolon: pos, isImplicit: true)
        default:
            let start = pos
            reportExpected("statement", at: start)
            recover()
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
            next()
            let rhs = parseExprList()
            if rhs.count > 1 || x.count > 1 {
                reportError("Assignment macros only permit a single values", at: rhs[0].start)
            }
            let operation = Binary(lhs: x[0], op: operatorFor(assignMacro: tok), opPos: pos, rhs: rhs[0], type: nil, irOp: nil, irLCast: nil, irRCast: nil, isPointerArithmetic: nil)
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
                next()
                let values = parseExprList()
                return Declaration(names: names, explicitType: nil, values: values, isConstant: false, callconv: nil, linkname: nil, entities: nil)
            } else if tok == .colon {
                next()
                let values = parseExprList()
                return Declaration(names: names, explicitType: nil, values: values, isConstant: true, callconv: nil, linkname: nil, entities: nil)
            }
            let type = parseType()
            switch tok {
            case .assign:
                next()
                let values = parseExprList()
                return Declaration(names: names, explicitType: type, values: values, isConstant: false, callconv: nil, linkname: nil, entities: nil)
            case .colon:
                next()
                let values = parseExprList()
                return Declaration(names: names, explicitType: type, values: values, isConstant: true, callconv: nil, linkname: nil, entities: nil)
            default:
                return Declaration(names: names, explicitType: type, values: [], isConstant: false, callconv: nil, linkname: nil, entities: nil)
            }
        case .in:
            return IdentList(idents: x)
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
        return Branch(token: token, label: label, target: nil, start: start)
    }

    mutating func parseIfStmt() -> If {
        let keyword = eatToken()
        let cond = parseExpr()
        if tok == .semicolon {
            // dummy terminator to prevent confusion with composite lits
            next()
        }
        // Note: parseStmt will expectTerm
        let body = parseStmt()
        var els_: Stmt?
        if tok == .else {
            next()
            els_ = parseStmt()
        }
        return If(keyword: keyword, cond: cond, body: body, els: els_)
    }

    mutating func parseSwitchStmt() -> Switch {
        let keyword = eatToken()
        var match: Expr?
        if tok != .lbrace && tok != .semicolon {
            match = parseExpr()
        }
        if tok == .semicolon {
            // dummy terminator to prevent confusion with composite lits
            next()
        }
        expect(.lbrace)
        var cases: [CaseClause] = [parseCaseClause()]
        while tok == .case {
            cases.append(parseCaseClause())
        }
        let rbrace = expect(.rbrace)
        expectTerm()
        return Switch(keyword: keyword, match: match, cases: cases, rbrace: rbrace, label: nil)
    }

    mutating func parseCaseClause() -> CaseClause {
        let keyword = eatToken()
        var match: Expr?
        if tok != .colon {
            match = parseExpr()
        }
        let colon = expect(.colon)
        let body = parseStmtList()
        let block = Block(lbrace: colon, stmts: body, rbrace: body.last?.end ?? colon)
        return CaseClause(keyword: keyword, match: match, colon: colon, block: block, label: nil)
    }

    mutating func parseForStmt() -> Stmt {
        let keyword = eatToken()
        var s1, s2, s3: Stmt?
        if tok != .lbrace && tok != .semicolon {
            s2 = parseSimpleStmt()
            if let idents = s2 as? IdentList {
                let names: [Ident] = idents.idents.flatMap {
                    guard let name = $0 as? Ident else {
                        reportError("Expected an identifier", at: $0.start)
                        return nil
                    }

                    return name
                }

                expect(.in)
                let aggregate = parseExpr()
                expectTerm() // Scanner inserts a terminator
                let body = parseBlock()
                expectTerm()
                return ForIn(keyword: keyword, names: names, aggregate: aggregate, body: body, breakLabel: nil, continueLabel: nil, element: nil, index: nil, checked: nil)
            }
        }
        // Note: Scanner inserts a semicolon with '{' as the lit
        //  This prevents interpreting the last stmt as a composite lit
        if tok == .semicolon, lit != "{" {
            next()
            s1 = s2
            s2 = nil
            if tok != .semicolon {
                s2 = parseSimpleStmt()
            }
            expectTerm()
            if tok != .lbrace && !(tok == .semicolon && lit == "{") {
                s3 = parseSimpleStmt()
            }
        }
        expectTerm() // Scanner inserts a terminator
        let body = parseBlock()
        expectTerm()
        var cond: Expr?
        if let s2 = s2 as? ExprStmt {
            cond = s2.expr
        } else if let s2 = s2 {
            reportExpected("expression", at: s2.start)
            cond = BadExpr(start: s2.start, end: s2.end)
        }
        return For(keyword: keyword, initializer: s1, cond: cond, step: s3, body: body, breakLabel: nil, continueLabel: nil)
    }
}


// - MARK: Directives

extension Parser {

    mutating func parseLeadingDirective(foreign: Bool = false) -> Stmt {
        let name = lit
        let directive = eatToken()
        switch LeadingDirective(rawValue: name) {
        case .import?:
            let path = parseExpr()
            var alias: Ident?
            var importSymbolsIntoScope = false
            if tok == .ident {
                if lit == "_" {
                    next()
                    importSymbolsIntoScope = true
                } else {
                    alias = parseIdent()
                }
            } else if tok != .semicolon {
                reportError("Expected identifier to bind imported or terminator", at: pos)
            }
            expectTerm()

            let i = Import(directive: directive, alias: alias, path: path, importSymbolsIntoScope: importSymbolsIntoScope, exportSymbolsOutOfScope: true, resolvedName: nil, scope: nil)
            file.add(import: i, importedFrom: file)
            return i
        case .use?:
            let path = parseExpr()
            var alias: Ident?
            var importSymbolsIntoScope = false
            if tok == .ident {
                alias = parseIdent()
            } else if tok == .ident && lit == "_" {
                next()
                importSymbolsIntoScope = true
            } else if tok != .semicolon {
                reportError("Expected identifier to bind imported or terminator", at: pos)
            }
            expectTerm()

            let i = Import(directive: directive, alias: alias, path: path, importSymbolsIntoScope: importSymbolsIntoScope, exportSymbolsOutOfScope: false, resolvedName: nil, scope: nil)
            file.add(import: i, importedFrom: file)
            return i
        case .library?:
            let path = parseExpr()
            var alias: Ident?
            if tok == .ident {
                alias = parseIdent()
            }
            expectTerm()
            return Library(directive: directive, path: path, alias: alias, resolvedName: nil)
        case .foreign?:
            let library = parseIdent()
            allowNewline()
            var x: Stmt
            switch tok {
            case .lbrace:
                x = parseDeclBlock(foreign: true)
            case .directive:
                x = parseLeadingDirective(foreign: true)
            default:
                let decl = parseDeclForBlock(foreign: true)
                x = Foreign(directive: directive, library: library, decl: decl, linkname: nil, callconv: nil)
            }
            return x
        case .callconv?:
            let conv = parseStringLit()
            allowNewline()
            var x: Stmt
            if tok == .directive {
                x = parseLeadingDirective(foreign: foreign)
            } else if tok == .lbrace {
                x = parseDeclBlock(foreign: foreign)
            } else {
                x = parseDeclForBlock(foreign: foreign)
            }

            switch x {
            case let block as DeclBlock:
                // TODO: Take normal block and convert to declblock
                block.callconv = conv.constant as! String!
            case let decl as CallConvApplicable:
                decl.callconv = conv.constant as! String!
            default:
                reportExpected("individual or block of declarations", at: x.start)
                recover()
                return BadStmt(start: directive, end: x.end)
            }
            return x
        case .linkprefix?:
            // link prefix is only permitted on decl blocks and must be the last directive
            let linkprefix = parseStringLit()
            allowNewline()
            let block = parseDeclBlock(foreign: foreign)
            block.linkprefix = linkprefix.constant as! String!
            return block

        default:
            if TrailingDirective(rawValue: name) != nil {
                reportError("'\(name)' is a trailing directive", at: directive)
            } else {
                reportError("Unknown leading directive '\(name)'", at: directive)
            }
        }
        let end = self.pos
        recover()
        return BadStmt(start: directive, end: end)
    }

    @discardableResult
    mutating func parseTrailingDirectives(for decl: Stmt) -> Stmt {
        guard tok == .directive else {
            expectTerm()
            return decl
        }
        let name = lit
        let directive = eatToken()
        switch TrailingDirective(rawValue: name) {
        case .linkname?:
            let linkname = parseStringLit()
            guard let d = decl as? Declaration else {
                reportExpected("declaration", at: decl.start)
                return decl
            }
            if d.linkname != nil {
                reportError("Duplicate linkname", at: directive)
            }
            d.linkname = linkname.constant as! String!
            expectTerm()
            return d
        default:
            if LeadingDirective(rawValue: name) != nil {
                reportError("'\(name)' is a leading directive", at: directive)
            } else {
                reportError("Unknown trailing directive '\(name)'", at: directive)
            }
            expectTerm()
            return decl
        }
    }

    mutating func parseDeclBlock(foreign: Bool) -> DeclBlock {
        let lbrace = eatToken()
        let decls = parseDeclList(foreign: foreign).flatMap({ $0 as? Declaration })
        let rbrace = expect(.rbrace)
        expectTerm()
        return DeclBlock(lbrace: lbrace, decls: decls, rbrace: rbrace, isForeign: foreign, linkprefix: nil, callconv: nil)
    }

    mutating func parseDeclForBlock(foreign: Bool) -> Decl {
        if tok == .directive {
            let x = parseLeadingDirective(foreign: foreign)
            guard let decl = x as? Decl else {
                reportExpected("declaration", at: x.start)
                parseTrailingDirectives(for: x)
                recover()
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
            next()
            let end = pos
            recover()
            return BadDecl(start: name.start, end: end)
        } else if tok == .colon {
            next()
            let type = parseType()
            let decl = Declaration(names: [name], explicitType: type, values: [], isConstant: true, callconv: nil, linkname: nil, entities: nil)
            return parseTrailingDirectives(for: decl) as! Decl
        } else {
            let type = parseType()
            let decl = Declaration(names: [name], explicitType: type, values: [], isConstant: false, callconv: nil, linkname: nil, entities: nil)
            return parseTrailingDirectives(for: decl) as! Decl
        }
    }
}


// - MARK: Helpers

extension Parser {

    mutating func next0() {
        (pos, tok, lit) = scanner.scan()
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
            next0()
        }
        return list
    }

    mutating func next() {
        next0()
        consumeComments()
    }

    func operatorFor(assignMacro: Token) -> Token {
        assert(Token(rawValue: Token.assignAdd.rawValue - 10)! == .add)

        return Token(rawValue: assignMacro.rawValue - 10)!
    }

    static let lowestPrecedence  = 0
    static let unaryPrecedence   = 7
    static let highestPrecedence = 8

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

    func unquote(_ s: String) -> String {
        var s = s

        s = String(s.dropFirst().dropLast())

        var index = s.startIndex
        while index < s.endIndex {
            guard s[index] == "\\" else {
                index = s.index(after: index)
                continue
            }
            s.remove(at: index)
            var char: Character
            switch s[index] {
            case "a":  char = "\u{0007}" // alert or bell
            case "b":  char = "\u{0008}" // backspace
            case "f":  char = "\u{000c}" // form feed
            case "n":  char = "\u{000a}" // line feed or newline
            case "r":  char = "\u{000d}" // carriage return
            case "t":  char = "\u{0009}" // horizontal tab
            case "v":  char = "\u{000b}" // vertical tab
            case "\\": char = "\u{005c}" // backslash
            case "\"": char = "\u{0022}" // double quote
            default:
                let startIndex = index
                var n = 0
                switch s[index] {
                case "x":
                    n = 2
                case "u":
                    n = 4
                case "U":
                    n = 8
                default:
                    assert(!file.errors.isEmpty, "Unknown escape sequences should be caught in the scanner")
                    return s
                }

                var val: UInt32 = 0
                for _ in 0 ..< n {
                    index = s.index(after: index)
                    assert(s[index].unicodeScalars.count == 1)
                    let x = digitVal(s[index].unicodeScalars.first!)
                    val = val << 4 | UInt32(x)
                }

                index = s.index(after: index)
                let scalar = Unicode.Scalar(val)!
                let character = Character(scalar)
                s.replaceSubrange(startIndex ..< index, with: [character])
                index = s.index(after: startIndex)

                continue
            }
            s.replaceSubrange(index ..< s.index(after: index), with: [char])
        }

        return s
    }
}


// - MARK: Errors

extension Parser {

    mutating func recover() {
        var startOfLine: Pos?
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
            case .colon, .assign,
                 .assignAdd, .assignSub, .assignMul, .assignQuo, .assignRem,
                 .assignAnd, .assignXor, .assignShl, .assignShr, .assignOr:
                if let startOfLine = startOfLine {
                    scanner.set(offset: Int(file.offset(pos: startOfLine)))
                    return
                }
            case .semicolon:
                startOfLine = pos
            case .eof:
                return
            default:
                break
            }
            next()
        }
    }

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
                recover()
            }
        }
    }

    mutating func allowNewline() {
        if tok == .semicolon && lit == "\n" {
            next()
        }
    }

    mutating func allowTerminator() {
        if tok == .semicolon {
            next()
        }
    }

    mutating func atComma(in context: String, _ follow: Token, function: StaticString = #function, line: UInt = #line) -> Bool {
        if tok == .comma {
            return true
        }
        if tok != follow {
            var msg = "Missing ','"
            if tok == .semicolon && lit == "\n" {
                next()
                if tok == follow { return false }
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

