
protocol Node: class {
    var start: Pos { get }
    var end: Pos { get }
}

protocol Expr: Node {}
protocol Stmt: Node {}
protocol Decl: Stmt {}
protocol LinknameApplicable: Stmt {
    var linkname: String? { get set }
}
protocol CallConvApplicable: Stmt {
    var callconv: String? { get set }
}

class Comment: Node {
    /// Position of the '/' starting the comment
    var slash: Pos

    /// Comment text (excluding '\n' for line comments)
    var text: String

    var start: Pos { return slash }
    var end: Pos {
        return start + text.count
    }

// sourcery:inline:auto:Comment.Init
init(slash: Pos, text: String) {
    self.slash = slash
    self.text = text
}
// sourcery:end
}


// MARK: Expressions

class StructField: Expr {
    var names: [Ident]
    var colon: Pos
    var type: Expr

    var start: Pos { return names.first?.start ?? type.start }
    var end: Pos { return type.end }

// sourcery:inline:auto:StructField.Init
init(names: [Ident], colon: Pos, type: Expr) {
    self.names = names
    self.colon = colon
    self.type = type
}
// sourcery:end
}

class BadExpr: Expr {
    var start: Pos
    var end: Pos

// sourcery:inline:auto:BadExpr.Init
init(start: Pos, end: Pos) {
    self.start = start
    self.end = end
}
// sourcery:end
}

class Ident: Expr {
    var start: Pos
    var name: String
    var end: Pos { return start + name.count }

// sourcery:inline:auto:Ident.Init
init(start: Pos, name: String) {
    self.start = start
    self.name = name
}
// sourcery:end
}

class Ellipsis: Expr {
    var start: Pos
    var element: Expr?
    var end: Pos { return start + 2 }

// sourcery:inline:auto:Ellipsis.Init
init(start: Pos, element: Expr?) {
    self.start = start
    self.element = element
}
// sourcery:end
}

class BasicLit: Expr {
    var start: Pos
    var token: Token
    var value: String
    var end: Pos { return start + value.count }

// sourcery:inline:auto:BasicLit.Init
init(start: Pos, token: Token, value: String) {
    self.start = start
    self.token = token
    self.value = value
}
// sourcery:end
}

class Parameter: Expr {
    var names: [(poly: Bool, Ident)]
    var type: Expr

    var start: Pos { return names.first!.poly ? names.first!.1.start - 1 : names.first!.1.start }
    var end: Pos { return type.end }

// sourcery:inline:auto:Parameter.Init
init(names: [(poly: Bool, Ident)], type: Expr) {
    self.names = names
    self.type = type
}
// sourcery:end
}

class ParameterList: Node {
    var lparen: Pos
    var list: [Parameter]
    var rparen: Pos

    var start: Pos { return lparen }
    var end: Pos { return rparen }

// sourcery:inline:auto:ParameterList.Init
init(lparen: Pos, list: [Parameter], rparen: Pos) {
    self.lparen = lparen
    self.list = list
    self.rparen = rparen
}
// sourcery:end
}

class ResultList: Expr {
    var lparen: Pos?
    var types: [Expr]
    var rparen: Pos?

    var start: Pos {
        return lparen ?? types.first!.start
    }
    var end: Pos {
        return rparen ?? types.last!.end
    }

// sourcery:inline:auto:ResultList.Init
init(lparen: Pos?, types: [Expr], rparen: Pos?) {
    self.lparen = lparen
    self.types = types
    self.rparen = rparen
}
// sourcery:end
}

class FuncLit: Expr {
    var keyword: Pos
    var params: ParameterList
    var results: ResultList
    var body: Block

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:FuncLit.Init
init(keyword: Pos, params: ParameterList, results: ResultList, body: Block) {
    self.keyword = keyword
    self.params = params
    self.results = results
    self.body = body
}
// sourcery:end
}

class ForeignFuncLit: Expr {
    var keyword: Pos
    var params: ParameterList
    var results: ResultList

    var start: Pos { return keyword }
    var end: Pos { return results.end }

// sourcery:inline:auto:ForeignFuncLit.Init
init(keyword: Pos, params: ParameterList, results: ResultList) {
    self.keyword = keyword
    self.params = params
    self.results = results
}
// sourcery:end
}

class CompositeLit: Expr {
    var type: Expr
    var lbrace: Pos
    var elements: [Expr]
    var rbrace: Pos

    var start: Pos { return type.start }
    var end: Pos { return rbrace }

// sourcery:inline:auto:CompositeLit.Init
init(type: Expr, lbrace: Pos, elements: [Expr], rbrace: Pos) {
    self.type = type
    self.lbrace = lbrace
    self.elements = elements
    self.rbrace = rbrace
}
// sourcery:end
}

class Paren: Expr {
    var lparen: Pos
    var element: Expr
    var rparen: Pos

    var start: Pos { return lparen }
    var end: Pos { return rparen }

// sourcery:inline:auto:Paren.Init
init(lparen: Pos, element: Expr, rparen: Pos) {
    self.lparen = lparen
    self.element = element
    self.rparen = rparen
}
// sourcery:end
}

class Selector: Expr {
    var rec: Expr
    var sel: Ident

    var start: Pos { return rec.start }
    var end: Pos { return sel.end }

// sourcery:inline:auto:Selector.Init
init(rec: Expr, sel: Ident) {
    self.rec = rec
    self.sel = sel
}
// sourcery:end
}

class Call: Expr {
    var fun: Expr
    var lparen: Pos
    var args: [Expr]
    var rparen: Pos

    var start: Pos { return fun.start }
    var end: Pos { return rparen }

// sourcery:inline:auto:Call.Init
init(fun: Expr, lparen: Pos, args: [Expr], rparen: Pos) {
    self.fun = fun
    self.lparen = lparen
    self.args = args
    self.rparen = rparen
}
// sourcery:end
}

class Unary: Expr {
    var start: Pos
    var op: Token
    var element: Expr

    var end: Pos { return element.end }

// sourcery:inline:auto:Unary.Init
init(start: Pos, op: Token, element: Expr) {
    self.start = start
    self.op = op
    self.element = element
}
// sourcery:end
}

class Binary: Expr {
    var lhs: Expr
    var op: Token
    var opPos: Pos
    var rhs: Expr

    var start: Pos { return lhs.start }
    var end: Pos { return rhs.end }

// sourcery:inline:auto:Binary.Init
init(lhs: Expr, op: Token, opPos: Pos, rhs: Expr) {
    self.lhs = lhs
    self.op = op
    self.opPos = opPos
    self.rhs = rhs
}
// sourcery:end
}

class Ternary: Expr {
    var cond: Expr
    var qmark: Pos
    var then: Expr?
    var colon: Pos
    var els: Expr

    var start: Pos { return cond.start }
    var end: Pos { return els.end }

// sourcery:inline:auto:Ternary.Init
init(cond: Expr, qmark: Pos, then: Expr?, colon: Pos, els: Expr) {
    self.cond = cond
    self.qmark = qmark
    self.then = then
    self.colon = colon
    self.els = els
}
// sourcery:end
}

class KeyValue: Expr {
    var key: Expr
    var colon: Pos
    var value: Expr

    var start: Pos { return key.start }
    var end: Pos { return value.end }

// sourcery:inline:auto:KeyValue.Init
init(key: Expr, colon: Pos, value: Expr) {
    self.key = key
    self.colon = colon
    self.value = value
}
// sourcery:end
}

class PointerType: Expr {
    var star: Pos
    var type: Expr

    var start: Pos { return star }
    var end: Pos { return type.end }

// sourcery:inline:auto:PointerType.Init
init(star: Pos, type: Expr) {
    self.star = star
    self.type = type
}
// sourcery:end
}

class ArrayType: Expr {
    var lbrack: Pos
    var length: Expr
    var rbrack: Pos
    var type: Expr

    var start: Pos { return lbrack }
    var end: Pos { return type.end }

// sourcery:inline:auto:ArrayType.Init
init(lbrack: Pos, length: Expr, rbrack: Pos, type: Expr) {
    self.lbrack = lbrack
    self.length = length
    self.rbrack = rbrack
    self.type = type
}
// sourcery:end
}

class SliceType: Expr {
    var lbrack: Pos
    var rbrack: Pos
    var type: Expr

    var start: Pos { return lbrack }
    var end: Pos { return type.end }

// sourcery:inline:auto:SliceType.Init
init(lbrack: Pos, rbrack: Pos, type: Expr) {
    self.lbrack = lbrack
    self.rbrack = rbrack
    self.type = type
}
// sourcery:end
}

class StructType: Expr {
    var keyword: Pos
    var lbrace: Pos
    var fields: [StructField]
    var rbrace: Pos

    var start: Pos { return keyword }
    var end: Pos { return rbrace }

// sourcery:inline:auto:StructType.Init
init(keyword: Pos, lbrace: Pos, fields: [StructField], rbrace: Pos) {
    self.keyword = keyword
    self.lbrace = lbrace
    self.fields = fields
    self.rbrace = rbrace
}
// sourcery:end
}

class PolyType: Expr {
    var dollar: Pos
    var type: Expr

    var start: Pos { return dollar }
    var end: Pos { return type.end }

// sourcery:inline:auto:PolyType.Init
init(dollar: Pos, type: Expr) {
    self.dollar = dollar
    self.type = type
}
// sourcery:end
}

class VariadicType: Expr {
    var ellipsis: Pos
    var type: Expr

    var start: Pos { return ellipsis }
    var end: Pos { return type.end }

// sourcery:inline:auto:VariadicType.Init
init(ellipsis: Pos, type: Expr) {
    self.ellipsis = ellipsis
    self.type = type
}
// sourcery:end
}

class FuncType: Expr {
    var lparen: Pos
    var params: [Expr]
    var results: [Expr]

    var start: Pos { return lparen }
    var end: Pos { return results.last!.end }

// sourcery:inline:auto:FuncType.Init
init(lparen: Pos, params: [Expr], results: [Expr]) {
    self.lparen = lparen
    self.params = params
    self.results = results
}
// sourcery:end
}


// MARK: Statements

class BadStmt: Stmt {
    var start: Pos
    var end: Pos

// sourcery:inline:auto:BadStmt.Init
init(start: Pos, end: Pos) {
    self.start = start
    self.end = end
}
// sourcery:end
}

class Empty: Stmt {
    var semicolon: Pos
    // if true ';' was omitted from source
    var isImplicit: Bool

    var start: Pos { return semicolon }
    var end: Pos { return semicolon }

// sourcery:inline:auto:Empty.Init
init(semicolon: Pos, isImplicit: Bool) {
    self.semicolon = semicolon
    self.isImplicit = isImplicit
}
// sourcery:end
}

class Label: Stmt {
    var label: Ident
    var colon: Pos

    var start: Pos { return label.start }
    var end: Pos { return colon }

// sourcery:inline:auto:Label.Init
init(label: Ident, colon: Pos) {
    self.label = label
    self.colon = colon
}
// sourcery:end
}

class ExprStmt: Stmt {
    var expr: Expr

    var start: Pos { return expr.start }
    var end: Pos { return expr.end }

// sourcery:inline:auto:ExprStmt.Init
init(expr: Expr) {
    self.expr = expr
}
// sourcery:end
}

class Assign: Stmt {
    var lhs: [Expr]
    var equals: Pos
    var rhs: [Expr]

    var start: Pos { return lhs.first!.start }
    var end: Pos { return rhs.last!.end }

// sourcery:inline:auto:Assign.Init
init(lhs: [Expr], equals: Pos, rhs: [Expr]) {
    self.lhs = lhs
    self.equals = equals
    self.rhs = rhs
}
// sourcery:end
}

class Return: Stmt {
    var keyword: Pos
    var results: [Expr]

    var start: Pos { return keyword }
    var end: Pos { return results.last?.end ?? (keyword + "return".count) }

// sourcery:inline:auto:Return.Init
init(keyword: Pos, results: [Expr]) {
    self.keyword = keyword
    self.results = results
}
// sourcery:end
}

class Branch: Stmt {
    /// Keyword Token (break, continue, fallthrough)
    var token: Token
    var label: Ident?

    var start: Pos
    var end: Pos { return label?.end ?? (start + token.description.count) }

// sourcery:inline:auto:Branch.Init
init(token: Token, label: Ident?, start: Pos) {
    self.token = token
    self.label = label
    self.start = start
}
// sourcery:end
}

class Block: Stmt {
    var lbrace: Pos
    var stmts: [Stmt]
    var rbrace: Pos

    var start: Pos { return lbrace }
    var end: Pos { return rbrace }

// sourcery:inline:auto:Block.Init
init(lbrace: Pos, stmts: [Stmt], rbrace: Pos) {
    self.lbrace = lbrace
    self.stmts = stmts
    self.rbrace = rbrace
}
// sourcery:end
}

class If: Stmt {
    var keyword: Pos
    var cond: Expr
    var body: Node
    var els: Node?

    var start: Pos { return keyword }
    var end: Pos { return els?.end ?? body.end }

// sourcery:inline:auto:If.Init
init(keyword: Pos, cond: Expr, body: Node, els: Node?) {
    self.keyword = keyword
    self.cond = cond
    self.body = body
    self.els = els
}
// sourcery:end
}

class CaseClause: Stmt {
    var keyword: Pos
    var match: Expr?
    var colon: Pos
    var block: Block

    var start: Pos { return keyword }
    var end: Pos { return block.end }

// sourcery:inline:auto:CaseClause.Init
init(keyword: Pos, match: Expr?, colon: Pos, block: Block) {
    self.keyword = keyword
    self.match = match
    self.colon = colon
    self.block = block
}
// sourcery:end
}

class Switch: Stmt {
    var keyword: Pos
    var match: Expr?
    var block: Block

    var start: Pos { return keyword }
    var end: Pos { return block.end }

// sourcery:inline:auto:Switch.Init
init(keyword: Pos, match: Expr?, block: Block) {
    self.keyword = keyword
    self.match = match
    self.block = block
}
// sourcery:end
}

class For: Stmt {
    var keyword: Pos
    var initializer: Stmt?
    var cond: Expr?
    var post: Stmt?
    var body: Block

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:For.Init
init(keyword: Pos, initializer: Stmt?, cond: Expr?, post: Stmt?, body: Block) {
    self.keyword = keyword
    self.initializer = initializer
    self.cond = cond
    self.post = post
    self.body = body
}
// sourcery:end
}

// MARK: Declarations

class Import: Stmt {
    var directive: Pos
    var path: Expr
    var alias: Ident?
    var importSymbolsIntoScope: Bool
    var file: SourceFile?

    var start: Pos { return directive }
    var end: Pos { return alias?.end ?? path.end }

// sourcery:inline:auto:Import.Init
init(directive: Pos, path: Expr, alias: Ident?, importSymbolsIntoScope: Bool, file: SourceFile?) {
    self.directive = directive
    self.path = path
    self.alias = alias
    self.importSymbolsIntoScope = importSymbolsIntoScope
    self.file = file
}
// sourcery:end
}

class Library: Stmt {
    var directive: Pos
    var path: Expr
    var alias: Ident?

    var start: Pos { return directive }
    var end: Pos { return alias?.end ?? path.end }

// sourcery:inline:auto:Library.Init
init(directive: Pos, path: Expr, alias: Ident?) {
    self.directive = directive
    self.path = path
    self.alias = alias
}
// sourcery:end
}

class Foreign: Decl, LinknameApplicable, CallConvApplicable {
    var directive: Pos
    var library: Ident
    var decl: Decl

    var linkname: String?
    var callconv: String?

    var start: Pos { return directive }
    var end: Pos { return decl.end }

// sourcery:inline:auto:Foreign.Init
init(directive: Pos, library: Ident, decl: Decl, linkname: String?, callconv: String?) {
    self.directive = directive
    self.library = library
    self.decl = decl
    self.linkname = linkname
    self.callconv = callconv
}
// sourcery:end
}

class DeclBlock: Decl, CallConvApplicable {
    var block: Block

    var callconv: String?

    var start: Pos { return block.start }
    var end: Pos { return block.end }

// sourcery:inline:auto:DeclBlock.Init
init(block: Block, callconv: String?) {
    self.block = block
    self.callconv = callconv
}
// sourcery:end
}

class ValueDecl: Decl, LinknameApplicable, CallConvApplicable {
    var names: [Ident]
    var type: Expr?
    var values: [Expr]

    var callconv: String?
    var linkname: String?

    var start: Pos { return names.first!.start }
    var end: Pos { return values.first!.end }

// sourcery:inline:auto:ValueDecl.Init
init(names: [Ident], type: Expr?, values: [Expr], callconv: String?, linkname: String?) {
    self.names = names
    self.type = type
    self.values = values
    self.callconv = callconv
    self.linkname = linkname
}
// sourcery:end
}

class VariableDecl: Decl, LinknameApplicable, CallConvApplicable {
    var names: [Ident]
    var type: Expr?
    var values: [Expr]

    var callconv: String?
    var linkname: String?
    //    var flags: DeclarationFlags

    var start: Pos { return names.first!.start }
    var end: Pos { return values.first!.end }

// sourcery:inline:auto:VariableDecl.Init
init(names: [Ident], type: Expr?, values: [Expr], callconv: String?, linkname: String?) {
    self.names = names
    self.type = type
    self.values = values
    self.callconv = callconv
    self.linkname = linkname
}
// sourcery:end
}
