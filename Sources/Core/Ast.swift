
import LLVM

// NOTE: For code gen everything must also explicitly conform to Node.
protocol Node: class {
    var start: Pos { get }
    var end: Pos { get }
}
protocol Expr: Node {
    var type: Type! { get set }
}
protocol Stmt: Node {}
protocol TopLevelStmt: Stmt {}
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

class StructField: Node {
    var names: [Ident]
    var colon: Pos
    var explicitType: Expr

    var type: Type!

    var start: Pos { return names.first?.start ?? explicitType.start }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:StructField.Init
init(names: [Ident], colon: Pos, explicitType: Expr, type: Type!) {
    self.names = names
    self.colon = colon
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class BadExpr: Node, Expr {
    var start: Pos
    var end: Pos

    var type: Type! {
        get {
            return ty.invalid
        }
        set {}
    }

// sourcery:inline:auto:BadExpr.Init
init(start: Pos, end: Pos) {
    self.start = start
    self.end = end
}
// sourcery:end
}

class Nil: Node, Expr {
    var start: Pos
    var end: Pos {
        return start + 3
    }

    var type: Type!

// sourcery:inline:auto:Nil.Init
init(start: Pos, type: Type!) {
    self.start = start
    self.type = type
}
// sourcery:end
}

class Ident: Node, Expr {
    var start: Pos
    var name: String

    var entity: Entity!
    var type: Type!
    var cast: OpCode.Cast?
    var constant: Value?

    var end: Pos { return start + name.count }

// sourcery:inline:auto:Ident.Init
init(start: Pos, name: String, entity: Entity!, type: Type!, cast: OpCode.Cast?, constant: Value?) {
    self.start = start
    self.name = name
    self.entity = entity
    self.type = type
    self.cast = cast
    self.constant = constant
}
// sourcery:end
}

class Ellipsis: Node, Expr {
    var start: Pos
    var element: Expr?
    var type: Type!

    var end: Pos { return element?.end ?? (start + 2) }

// sourcery:inline:auto:Ellipsis.Init
init(start: Pos, element: Expr?, type: Type!) {
    self.start = start
    self.element = element
    self.type = type
}
// sourcery:end
}

class BasicLit: Node, Expr {
    var start: Pos
    var token: Token
    var text: String
    var flags: LiteralFlags
    var type: Type!
    var constant: Value!

    var end: Pos { return start + text.count }

// sourcery:inline:auto:BasicLit.Init
init(start: Pos, token: Token, text: String, flags: LiteralFlags, type: Type!, constant: Value!) {
    self.start = start
    self.token = token
    self.text = text
    self.flags = flags
    self.type = type
    self.constant = constant
}
// sourcery:end
}

class Parameter: Node {
    var dollar: Pos?
    var name: Ident
    var explicitType: Expr

    var entity: Entity!
    var type: Type! {
        return entity.type
    }

    var start: Pos { return dollar ?? name.start }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:Parameter.Init
init(dollar: Pos?, name: Ident, explicitType: Expr, entity: Entity!) {
    self.dollar = dollar
    self.name = name
    self.explicitType = explicitType
    self.entity = entity
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

class ResultList: Node {
    var lparen: Pos?
    var types: [Expr]
    var rparen: Pos?

    var start: Pos { return lparen ?? types.first!.start }
    var end: Pos { return rparen ?? types.last!.end }

// sourcery:inline:auto:ResultList.Init
init(lparen: Pos?, types: [Expr], rparen: Pos?) {
    self.lparen = lparen
    self.types = types
    self.rparen = rparen
}
// sourcery:end
}

class FuncLit: Node, Expr {
    var keyword: Pos
    var params: ParameterList
    var results: ResultList
    var body: Block
    var flags: FunctionFlags

    var type: Type!
    var checked: Checked!

    enum Checked {
        case regular(Scope)
        case polymorphic(declaringScope: Scope, specializations: [FunctionSpecialization])
    }

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:FuncLit.Init
init(keyword: Pos, params: ParameterList, results: ResultList, body: Block, flags: FunctionFlags, type: Type!, checked: Checked!) {
    self.keyword = keyword
    self.params = params
    self.results = results
    self.body = body
    self.flags = flags
    self.type = type
    self.checked = checked
}
// sourcery:end
}

class CompositeLit: Node, Expr {
    var explicitType: Expr
    var lbrace: Pos
    var elements: [KeyValue]
    var rbrace: Pos

    var type: Type!

    var start: Pos { return explicitType.start }
    var end: Pos { return rbrace }

// sourcery:inline:auto:CompositeLit.Init
init(explicitType: Expr, lbrace: Pos, elements: [KeyValue], rbrace: Pos, type: Type!) {
    self.explicitType = explicitType
    self.lbrace = lbrace
    self.elements = elements
    self.rbrace = rbrace
    self.type = type
}
// sourcery:end
}

class Paren: Node, Expr {
    var lparen: Pos
    var element: Expr
    var rparen: Pos

    var type: Type!

    var start: Pos { return lparen }
    var end: Pos { return rparen }

// sourcery:inline:auto:Paren.Init
init(lparen: Pos, element: Expr, rparen: Pos, type: Type!) {
    self.lparen = lparen
    self.element = element
    self.rparen = rparen
    self.type = type
}
// sourcery:end
}

class Selector: Node, Expr {
    var rec: Expr
    var sel: Ident

    var checked: Checked!
    var type: Type!
    var cast: OpCode.Cast?
    var constant: Value?

    enum Checked {
        case invalid
        case file(Entity)
        case `struct`(ty.Struct.Field)
        case array(ArrayMember)

        enum ArrayMember: Int {
            case raw
            case length
            case capacity
        }
    }

    var start: Pos { return rec.start }
    var end: Pos { return sel.end }

// sourcery:inline:auto:Selector.Init
init(rec: Expr, sel: Ident, checked: Checked!, type: Type!, cast: OpCode.Cast?, constant: Value?) {
    self.rec = rec
    self.sel = sel
    self.checked = checked
    self.type = type
    self.cast = cast
    self.constant = constant
}
// sourcery:end
}

class Subscript: Expr, Node {
    var rec: Expr
    var index: Expr

    var type: Type! 
    var checked: Checked!

    enum Checked {
        case array
        case dynamicArray
        case pointer
    }

    var start: Pos { return rec.start }
    var end: Pos { return index.end }

// sourcery:inline:auto:Subscript.Init
init(rec: Expr, index: Expr, type: Type!, checked: Checked!) {
    self.rec = rec
    self.index = index
    self.type = type
    self.checked = checked
}
// sourcery:end
}

class Call: Node, Expr {
    var fun: Expr
    var lparen: Pos
    var args: [Expr]
    var rparen: Pos

    var type: Type!
    var checked: Checked!

    var start: Pos { return fun.start }
    var end: Pos { return rparen }

    enum Checked {
        case call
        case specializedCall(FunctionSpecialization)
        case builtinCall(BuiltinFunction)
        case cast(OpCode.Cast)
    }

// sourcery:inline:auto:Call.Init
init(fun: Expr, lparen: Pos, args: [Expr], rparen: Pos, type: Type!, checked: Checked!) {
    self.fun = fun
    self.lparen = lparen
    self.args = args
    self.rparen = rparen
    self.type = type
    self.checked = checked
}
// sourcery:end
}

class Unary: Node, Expr {
    var start: Pos
    var op: Token
    var element: Expr

    var type: Type!

    var end: Pos { return element.end }

// sourcery:inline:auto:Unary.Init
init(start: Pos, op: Token, element: Expr, type: Type!) {
    self.start = start
    self.op = op
    self.element = element
    self.type = type
}
// sourcery:end
}

class Binary: Node, Expr {
    var lhs: Expr
    var op: Token
    var opPos: Pos
    var rhs: Expr

    var type: Type!

    var irOp: OpCode.Binary!
    var irLCast: OpCode.Cast!
    var irRCast: OpCode.Cast!
    var isPointerArithmetic: Bool!

    var start: Pos { return lhs.start }
    var end: Pos { return rhs.end }

// sourcery:inline:auto:Binary.Init
init(lhs: Expr, op: Token, opPos: Pos, rhs: Expr, type: Type!, irOp: OpCode.Binary!, irLCast: OpCode.Cast!, irRCast: OpCode.Cast!, isPointerArithmetic: Bool!) {
    self.lhs = lhs
    self.op = op
    self.opPos = opPos
    self.rhs = rhs
    self.type = type
    self.irOp = irOp
    self.irLCast = irLCast
    self.irRCast = irRCast
    self.isPointerArithmetic = isPointerArithmetic
}
// sourcery:end
}

class Ternary: Node, Expr {
    var cond: Expr
    var qmark: Pos
    var then: Expr?
    var colon: Pos
    var els: Expr

    var type: Type!

    var start: Pos { return cond.start }
    var end: Pos { return els.end }

// sourcery:inline:auto:Ternary.Init
init(cond: Expr, qmark: Pos, then: Expr?, colon: Pos, els: Expr, type: Type!) {
    self.cond = cond
    self.qmark = qmark
    self.then = then
    self.colon = colon
    self.els = els
    self.type = type
}
// sourcery:end
}

class KeyValue: Node, Expr {
    var key: Expr?
    var colon: Pos?
    var value: Expr

    var type: Type!
    var structField: ty.Struct.Field?

    var start: Pos { return key?.start ?? value.start }
    var end: Pos { return value.end }

// sourcery:inline:auto:KeyValue.Init
init(key: Expr?, colon: Pos?, value: Expr, type: Type!, structField: ty.Struct.Field?) {
    self.key = key
    self.colon = colon
    self.value = value
    self.type = type
    self.structField = structField
}
// sourcery:end
}

class PointerType: Node, Expr {
    var star: Pos
    var explicitType: Expr

    var type: Type!

    var start: Pos { return star }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:PointerType.Init
init(star: Pos, explicitType: Expr, type: Type!) {
    self.star = star
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class ArrayType: Node, Expr {
    var lbrack: Pos
    var length: Expr
    var rbrack: Pos
    var explicitType: Expr

    var type: Type!

    var start: Pos { return lbrack }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:ArrayType.Init
init(lbrack: Pos, length: Expr, rbrack: Pos, explicitType: Expr, type: Type!) {
    self.lbrack = lbrack
    self.length = length
    self.rbrack = rbrack
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class DynamicArrayType: Node, Expr {
    var lbrack: Pos
    var rbrack: Pos
    var explicitType: Expr

    var type: Type!
    
    var start: Pos { return lbrack }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:DynamicArrayType.Init
init(lbrack: Pos, rbrack: Pos, explicitType: Expr, type: Type!) {
    self.lbrack = lbrack
    self.rbrack = rbrack
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class SliceType: Node, Expr {
    var lbrack: Pos
    var rbrack: Pos
    var explicitType: Expr

    var type: Type!

    var start: Pos { return lbrack }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:SliceType.Init
init(lbrack: Pos, rbrack: Pos, explicitType: Expr, type: Type!) {
    self.lbrack = lbrack
    self.rbrack = rbrack
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class StructType: Node, Expr {
    var keyword: Pos
    var lbrace: Pos
    var fields: [StructField]
    var rbrace: Pos

    var type: Type!

    var start: Pos { return keyword }
    var end: Pos { return rbrace }

// sourcery:inline:auto:StructType.Init
init(keyword: Pos, lbrace: Pos, fields: [StructField], rbrace: Pos, type: Type!) {
    self.keyword = keyword
    self.lbrace = lbrace
    self.fields = fields
    self.rbrace = rbrace
    self.type = type
}
// sourcery:end
}

class PolyType: Node, Expr {
    var dollar: Pos
    var explicitType: Expr

    var type: Type!

    var start: Pos { return dollar }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:PolyType.Init
init(dollar: Pos, explicitType: Expr, type: Type!) {
    self.dollar = dollar
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class VariadicType: Node, Expr {
    var ellipsis: Pos
    var explicitType: Expr

    var isCvargs: Bool

    var type: Type!

    var start: Pos { return ellipsis }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:VariadicType.Init
init(ellipsis: Pos, explicitType: Expr, isCvargs: Bool, type: Type!) {
    self.ellipsis = ellipsis
    self.explicitType = explicitType
    self.isCvargs = isCvargs
    self.type = type
}
// sourcery:end
}

class FuncType: Node, Expr {
    var lparen: Pos
    var params: [Expr]
    var results: [Expr]
    var flags: FunctionFlags

    var type: Type!

    var start: Pos { return lparen }
    var end: Pos { return results.last!.end }

// sourcery:inline:auto:FuncType.Init
init(lparen: Pos, params: [Expr], results: [Expr], flags: FunctionFlags, type: Type!) {
    self.lparen = lparen
    self.params = params
    self.results = results
    self.flags = flags
    self.type = type
}
// sourcery:end
}


// MARK: Statements

class BadStmt: Node, TopLevelStmt, Stmt {
    var start: Pos
    var end: Pos

// sourcery:inline:auto:BadStmt.Init
init(start: Pos, end: Pos) {
    self.start = start
    self.end = end
}
// sourcery:end
}

class Empty: Node, Stmt {
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

class Label: Node, Stmt {
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

class ExprStmt: Node, Stmt {
    var expr: Expr

    var start: Pos { return expr.start }
    var end: Pos { return expr.end }

// sourcery:inline:auto:ExprStmt.Init
init(expr: Expr) {
    self.expr = expr
}
// sourcery:end
}

class Assign: Node, Stmt {
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

class Return: Node, Stmt {
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

class Branch: Node, Stmt {
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

class Block: Node, Stmt {
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

class If: Node, Stmt {
    var keyword: Pos
    var cond: Expr
    var body: Stmt
    var els: Stmt?

    var start: Pos { return keyword }
    var end: Pos { return els?.end ?? body.end }

// sourcery:inline:auto:If.Init
init(keyword: Pos, cond: Expr, body: Stmt, els: Stmt?) {
    self.keyword = keyword
    self.cond = cond
    self.body = body
    self.els = els
}
// sourcery:end
}

class CaseClause: Node, Stmt {
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

class Switch: Node, Stmt {
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

class For: Node, Stmt {
    var keyword: Pos
    var initializer: Stmt?
    var cond: Expr?
    var step: Stmt?
    var body: Block

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:For.Init
init(keyword: Pos, initializer: Stmt?, cond: Expr?, step: Stmt?, body: Block) {
    self.keyword = keyword
    self.initializer = initializer
    self.cond = cond
    self.step = step
    self.body = body
}
// sourcery:end
}

// MARK: Declarations

class Import: Node, TopLevelStmt {
    var directive: Pos
    var path: Expr
    var alias: Ident?
    var importSymbolsIntoScope: Bool
    var resolvedName: String?
    var scope: Scope!

    var start: Pos { return directive }
    var end: Pos { return alias?.end ?? path.end }

// sourcery:inline:auto:Import.Init
init(directive: Pos, path: Expr, alias: Ident?, importSymbolsIntoScope: Bool, resolvedName: String?, scope: Scope!) {
    self.directive = directive
    self.path = path
    self.alias = alias
    self.importSymbolsIntoScope = importSymbolsIntoScope
    self.resolvedName = resolvedName
    self.scope = scope
}
// sourcery:end
}

class Library: Node, TopLevelStmt {
    var directive: Pos
    var path: Expr
    var alias: Ident?

    var resolvedName: String?

    var start: Pos { return directive }
    var end: Pos { return alias?.end ?? path.end }

// sourcery:inline:auto:Library.Init
init(directive: Pos, path: Expr, alias: Ident?, resolvedName: String?) {
    self.directive = directive
    self.path = path
    self.alias = alias
    self.resolvedName = resolvedName
}
// sourcery:end
}

class Foreign: Node, TopLevelStmt, LinknameApplicable, CallConvApplicable {
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

class DeclBlock: Node, TopLevelStmt, CallConvApplicable {
    var lbrace: Pos
    var decls: [Declaration]
    var rbrace: Pos

    var isForeign: Bool

    var linkprefix: String?
    var callconv: String?

    var start: Pos { return lbrace }
    var end: Pos { return rbrace }

// sourcery:inline:auto:DeclBlock.Init
init(lbrace: Pos, decls: [Declaration], rbrace: Pos, isForeign: Bool, linkprefix: String?, callconv: String?) {
    self.lbrace = lbrace
    self.decls = decls
    self.rbrace = rbrace
    self.isForeign = isForeign
    self.linkprefix = linkprefix
    self.callconv = callconv
}
// sourcery:end
}

class Declaration: Node, TopLevelStmt, Decl, LinknameApplicable, CallConvApplicable {
    var names: [Ident]
    var explicitType: Expr?
    var values: [Expr]

    var isConstant: Bool

    var callconv: String?
    var linkname: String?

    var entities: [Entity]!

    var start: Pos { return names.first!.start }
    var end: Pos { return values.first!.end }

// sourcery:inline:auto:Declaration.Init
init(names: [Ident], explicitType: Expr?, values: [Expr], isConstant: Bool, callconv: String?, linkname: String?, entities: [Entity]!) {
    self.names = names
    self.explicitType = explicitType
    self.values = values
    self.isConstant = isConstant
    self.callconv = callconv
    self.linkname = linkname
    self.entities = entities
}
// sourcery:end
}

class BadDecl: Node, Decl {
    var start: Pos
    var end: Pos

// sourcery:inline:auto:BadDecl.Init
init(start: Pos, end: Pos) {
    self.start = start
    self.end = end
}
// sourcery:end
}

struct LiteralFlags: OptionSet {
    var rawValue: UInt8

    static let none             = LiteralFlags(rawValue: 0b0000)
    static let stackAllocate    = LiteralFlags(rawValue: 0b0001)
}

struct FunctionFlags: OptionSet {
    var rawValue: UInt8

    static let none             = FunctionFlags(rawValue: 0b0000)
    static let variadic         = FunctionFlags(rawValue: 0b0001)
    static let cVariadic        = FunctionFlags(rawValue: 0b0011) // implies variadic
    static let discardable      = FunctionFlags(rawValue: 0b0100)
    static let specialization   = FunctionFlags(rawValue: 0b1000)
}

class FunctionSpecialization {
    let specializedTypes: [Type]
    let strippedType: ty.Function
    let generatedFunctionNode: FuncLit
    var llvm: Function?

// sourcery:inline:auto:FunctionSpecialization.Init
init(specializedTypes: [Type], strippedType: ty.Function, generatedFunctionNode: FuncLit, llvm: Function?) {
    self.specializedTypes = specializedTypes
    self.strippedType = strippedType
    self.generatedFunctionNode = generatedFunctionNode
    self.llvm = llvm
}
// sourcery:end
}
