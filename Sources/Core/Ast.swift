
// NOTE: For code gen everything must also explicitly conform to Node.
protocol Node: class {
    var start: Pos { get }
    var end: Pos { get }
}
protocol Expr: Node {
    var type: Type { get set }
}
protocol Stmt: Node {}
protocol TopLevelStmt: Stmt {}
protocol Decl: TopLevelStmt {
    var dependsOn: Set<Entity> { get set }
    var checked: Bool { get set }
    var emitted: Bool { get set }
}
protocol LinknameApplicable: Stmt {
    var linkname: String? { get set }
}
protocol CallConvApplicable: Stmt {
    var callconv: String? { get set }
}
protocol TestApplicable: Stmt {
    var isTest: Bool { get set }
}

protocol Convertable: Expr {
    var conversion: (from: Type, to: Type)? { get set }
}

protocol HasConstantValue: Expr {
    var constant: Value? { get set }
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

    var type: Type = ty.invalid

    var start: Pos { return names.first?.start ?? explicitType.start }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:StructField.Init
init(names: [Ident], colon: Pos, explicitType: Expr, type: Type = ty.invalid) {
    self.names = names
    self.colon = colon
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class EnumCase: Node {
    var name: Ident
    var value: Expr?

    var start: Pos { return name.start }
    var end: Pos { return value?.end ?? name.end }

// sourcery:inline:auto:EnumCase.Init
init(name: Ident, value: Expr?) {
    self.name = name
    self.value = value
}
// sourcery:end
}

class BadExpr: Node, Expr {
    var start: Pos
    var end: Pos

    var type: Type {
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

class LocationDirective: Node, Expr, Convertable, HasConstantValue {
    var directive: Pos
    var kind: LoneDirective

    var type: Type = ty.invalid
    var constant: Value? = nil
    var conversion: (from: Type, to: Type)? = nil

    var start: Pos { return directive }
    var end: Pos { return directive + kind.rawValue.count }

// sourcery:inline:auto:LocationDirective.Init
init(directive: Pos, kind: LoneDirective, type: Type = ty.invalid, constant: Value? = nil, conversion: (from: Type, to: Type)? = nil) {
    self.directive = directive
    self.kind = kind
    self.type = type
    self.constant = constant
    self.conversion = conversion
}
// sourcery:end
}

class Nil: Node, Expr {
    var start: Pos
    var end: Pos {
        return start + 3
    }

    var type: Type = ty.invalid

// sourcery:inline:auto:Nil.Init
init(start: Pos, type: Type = ty.invalid) {
    self.start = start
    self.type = type
}
// sourcery:end
}

class Ident: Node, Expr, Convertable, HasConstantValue {
    var start: Pos
    var name: String

    var entity: Entity! = nil
    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil
    var constant: Value? = nil


    var end: Pos { return start + name.count }

// sourcery:inline:auto:Ident.Init
init(start: Pos, name: String, entity: Entity! = nil, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil, constant: Value? = nil) {
    self.start = start
    self.name = name
    self.entity = entity
    self.type = type
    self.conversion = conversion
    self.constant = constant
}
// sourcery:end
}

class Ellipsis: Node, Expr {
    var start: Pos
    var element: Expr?

    var type: Type = ty.invalid

    var end: Pos { return element?.end ?? (start + 2) }

// sourcery:inline:auto:Ellipsis.Init
init(start: Pos, element: Expr?, type: Type = ty.invalid) {
    self.start = start
    self.element = element
    self.type = type
}
// sourcery:end
}

class BasicLit: Node, Expr, Convertable, HasConstantValue {
    var start: Pos
    var token: Token
    var text: String

    var type: Type = ty.invalid
    var constant: Value? = nil
    var conversion: (from: Type, to: Type)? = nil

    var end: Pos { return start + text.count }

// sourcery:inline:auto:BasicLit.Init
init(start: Pos, token: Token, text: String, type: Type = ty.invalid, constant: Value? = nil, conversion: (from: Type, to: Type)? = nil) {
    self.start = start
    self.token = token
    self.text = text
    self.type = type
    self.constant = constant
    self.conversion = conversion
}
// sourcery:end
}

class PolyParameterList: Node {
    var lparen: Pos
    var list: [PolyType]
    var rparen: Pos

    var start: Pos { return lparen }
    var end: Pos { return rparen }

// sourcery:inline:auto:PolyParameterList.Init
init(lparen: Pos, list: [PolyType], rparen: Pos) {
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

// NOTE: used in `for x, y in z` statements
class IdentList: Node, Stmt {
    var idents: [Expr]

    var start: Pos { return idents.first!.start }
    var end: Pos { return idents.last!.end }

// sourcery:inline:auto:IdentList.Init
init(idents: [Expr]) {
    self.idents = idents
}
// sourcery:end
}

class FuncLit: Node, Expr {
    var keyword: Pos
    var explicitType: FuncType
    var body: Block
    var flags: FunctionFlags

    var type: Type = ty.invalid
    var params: [Entity]! = nil
    var checked: Checked = .invalid
    var labels: [Ident]? {
        return explicitType.labels
    }

    enum Checked {
        case invalid
        case regular(Scope)
        case polymorphic(declaringScope: Scope, specializations: [FunctionSpecialization])
    }

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:FuncLit.Init
init(keyword: Pos, explicitType: FuncType, body: Block, flags: FunctionFlags, type: Type = ty.invalid, params: [Entity]! = nil, checked: Checked = .invalid) {
    self.keyword = keyword
    self.explicitType = explicitType
    self.body = body
    self.flags = flags
    self.type = type
    self.params = params
    self.checked = checked
}
// sourcery:end
}

class CompositeLit: Node, Expr {
    var explicitType: Expr?
    var lbrace: Pos
    var elements: [KeyValue]
    var rbrace: Pos

    var type: Type = ty.invalid

    var start: Pos { return explicitType?.start ?? lbrace }
    var end: Pos { return rbrace }

// sourcery:inline:auto:CompositeLit.Init
init(explicitType: Expr?, lbrace: Pos, elements: [KeyValue], rbrace: Pos, type: Type = ty.invalid) {
    self.explicitType = explicitType
    self.lbrace = lbrace
    self.elements = elements
    self.rbrace = rbrace
    self.type = type
}
// sourcery:end
}

class Paren: Node, Expr, Convertable {
    var lparen: Pos
    var element: Expr
    var rparen: Pos

    var type: Type {
        get {
            return element.type
        }
        set {
            element.type = newValue
        }
    }
    var conversion: (from: Type, to: Type)? = nil

    var start: Pos { return lparen }
    var end: Pos { return rparen }

// sourcery:inline:auto:Paren.Init
init(lparen: Pos, element: Expr, rparen: Pos, conversion: (from: Type, to: Type)? = nil) {
    self.lparen = lparen
    self.element = element
    self.rparen = rparen
    self.conversion = conversion
}
// sourcery:end
}

class Selector: Node, Expr, Convertable, HasConstantValue {
    var rec: Expr
    var sel: Ident

    var checked: Checked = .invalid
    var type: Type = ty.invalid
    var levelsOfIndirection: Int! = nil
    var conversion: (from: Type, to: Type)? = nil
    var constant: Value? = nil

    enum Checked {
        case invalid
        case file(Entity)
        case `struct`(ty.Struct.Field)
        case `enum`(ty.Enum.Case)
        case union(ty.Union, ty.Union.Case)
        case unionTag
        case array(ArrayMember)
        case staticLength(Int)
        case scalar(Int)
        case swizzle([Int])
        case anyData
        case anyType

        enum ArrayMember: Int {
            case raw
            case length
            case capacity
        }
    }

    var start: Pos { return rec.start }
    var end: Pos { return sel.end }

// sourcery:inline:auto:Selector.Init
init(rec: Expr, sel: Ident, checked: Checked = .invalid, type: Type = ty.invalid, levelsOfIndirection: Int! = nil, conversion: (from: Type, to: Type)? = nil, constant: Value? = nil) {
    self.rec = rec
    self.sel = sel
    self.checked = checked
    self.type = type
    self.levelsOfIndirection = levelsOfIndirection
    self.conversion = conversion
    self.constant = constant
}
// sourcery:end
}

class Subscript: Expr, Node, Convertable {
    var rec: Expr
    let lbrack: Pos
    var index: Expr
    let rbrack: Pos

    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil

    var start: Pos { return rec.start }
    var end: Pos { return rbrack }

// sourcery:inline:auto:Subscript.Init
init(rec: Expr, lbrack: Pos, index: Expr, rbrack: Pos, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil) {
    self.rec = rec
    self.lbrack = lbrack
    self.index = index
    self.rbrack = rbrack
    self.type = type
    self.conversion = conversion
}
// sourcery:end
}

class Slice: Expr, Node {
    var rec: Expr
    var lbrack: Pos
    var lo: Expr?
    var hi: Expr?
    var rbrack: Pos

    var type: Type = ty.invalid

    // TODO: Slice with certain capacity?

    var start: Pos { return rec.start }
    var end: Pos { return rbrack }

// sourcery:inline:auto:Slice.Init
init(rec: Expr, lbrack: Pos, lo: Expr?, hi: Expr?, rbrack: Pos, type: Type = ty.invalid) {
    self.rec = rec
    self.lbrack = lbrack
    self.lo = lo
    self.hi = hi
    self.rbrack = rbrack
    self.type = type
}
// sourcery:end
}

class Cast: Node, Expr, Convertable {
    var keyword: Pos
    var kind: Token
    var explicitType: Expr?
    var expr: Expr

    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil

    var start: Pos { return keyword }
    var end: Pos { return expr.end }

// sourcery:inline:auto:Cast.Init
init(keyword: Pos, kind: Token, explicitType: Expr?, expr: Expr, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil) {
    self.keyword = keyword
    self.kind = kind
    self.explicitType = explicitType
    self.expr = expr
    self.type = type
    self.conversion = conversion
}
// sourcery:end
}

class Call: Node, Expr, Convertable {
    var fun: Expr
    var lparen: Pos
    var labels: [Ident?]
    var args: [Expr]
    var rparen: Pos

    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil
    var checked: Checked = .invalid

    var start: Pos { return fun.start }
    var end: Pos { return rparen }

    enum Checked {
        case invalid
        case call
        case specializedCall(FunctionSpecialization)
        case builtinCall(BuiltinFunction)
    }

// sourcery:inline:auto:Call.Init
init(fun: Expr, lparen: Pos, labels: [Ident?], args: [Expr], rparen: Pos, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil, checked: Checked = .invalid) {
    self.fun = fun
    self.lparen = lparen
    self.labels = labels
    self.args = args
    self.rparen = rparen
    self.type = type
    self.conversion = conversion
    self.checked = checked
}
// sourcery:end
}

class Unary: Node, Expr, Convertable {

    var start: Pos
    var op: Token
    var element: Expr

    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil

    var end: Pos { return element.end }

// sourcery:inline:auto:Unary.Init
init(start: Pos, op: Token, element: Expr, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil) {
    self.start = start
    self.op = op
    self.element = element
    self.type = type
    self.conversion = conversion
}
// sourcery:end
}

class Binary: Node, Expr, Convertable {
    var lhs: Expr
    var op: Token
    var opPos: Pos
    var rhs: Expr

    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil

    var flags: Flags = .none

    var start: Pos { return lhs.start }
    var end: Pos { return rhs.end }

    struct Flags: OptionSet {
        var rawValue: UInt8

        static let none    = Flags(rawValue: 0b0000)
        static let ptrMath = Flags(rawValue: 0b0100)
    }

// sourcery:inline:auto:Binary.Init
init(lhs: Expr, op: Token, opPos: Pos, rhs: Expr, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil, flags: Flags = .none) {
    self.lhs = lhs
    self.op = op
    self.opPos = opPos
    self.rhs = rhs
    self.type = type
    self.conversion = conversion
    self.flags = flags
}

// sourcery:end
}

class Ternary: Node, Expr, Convertable {
    var cond: Expr
    var qmark: Pos
    var then: Expr?
    var colon: Pos
    var els: Expr

    var type: Type = ty.invalid
    var conversion: (from: Type, to: Type)? = nil

    var start: Pos { return cond.start }
    var end: Pos { return els.end }

// sourcery:inline:auto:Ternary.Init
init(cond: Expr, qmark: Pos, then: Expr?, colon: Pos, els: Expr, type: Type = ty.invalid, conversion: (from: Type, to: Type)? = nil) {
    self.cond = cond
    self.qmark = qmark
    self.then = then
    self.colon = colon
    self.els = els
    self.type = type
    self.conversion = conversion
}
// sourcery:end
}

class KeyValue: Node, Expr, Convertable {
    var key: Expr?
    var colon: Pos?
    var value: Expr

    var type: Type = ty.invalid
    var checked: Checked = .invalid
    var conversion: (from: Type, to: Type)? = nil

    enum Checked {
        case invalid
        case unionCase(ty.Union.Case)
        case structField(ty.Struct.Field)
    }

    var start: Pos { return key?.start ?? value.start }
    var end: Pos { return value.end }

// sourcery:inline:auto:KeyValue.Init
init(key: Expr?, colon: Pos?, value: Expr, type: Type = ty.invalid, checked: Checked = .invalid, conversion: (from: Type, to: Type)? = nil) {
    self.key = key
    self.colon = colon
    self.value = value
    self.type = type
    self.checked = checked
    self.conversion = conversion
}
// sourcery:end
}

class PointerType: Node, Expr {
    var star: Pos
    var explicitType: Expr

    var type: Type = ty.invalid

    var start: Pos { return star }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:PointerType.Init
init(star: Pos, explicitType: Expr, type: Type = ty.invalid) {
    self.star = star
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class ArrayType: Node, Expr {
    var lbrack: Pos
    var length: Expr?
    var rbrack: Pos
    var explicitType: Expr

    var type: Type = ty.invalid

    var start: Pos { return lbrack }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:ArrayType.Init
init(lbrack: Pos, length: Expr?, rbrack: Pos, explicitType: Expr, type: Type = ty.invalid) {
    self.lbrack = lbrack
    self.length = length
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

    var type: Type = ty.invalid

    var start: Pos { return lbrack }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:SliceType.Init
init(lbrack: Pos, rbrack: Pos, explicitType: Expr, type: Type = ty.invalid) {
    self.lbrack = lbrack
    self.rbrack = rbrack
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class VectorType: Node, Expr {
    var lbrack: Pos
    var size: Expr
    var rbrack: Pos
    var explicitType: Expr

    var type: Type = ty.invalid

    var start: Pos { return lbrack }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:VectorType.Init
init(lbrack: Pos, size: Expr, rbrack: Pos, explicitType: Expr, type: Type = ty.invalid) {
    self.lbrack = lbrack
    self.size = size
    self.rbrack = rbrack
    self.explicitType = explicitType
    self.type = type
}
// sourcery:end
}

class StructType: Node, Expr {
    var keyword: Pos
    var directives: Set<TypeDirective>
    var lbrace: Pos
    var fields: [StructField]
    var rbrace: Pos

    var type: Type = ty.invalid
    var checked: Checked = .invalid

    enum Checked {
        case invalid
        case regular(Scope)
        case polymorphic(declaringScope: Scope, specializations: [StructSpecialization])
    }

    var start: Pos { return keyword }
    var end: Pos { return rbrace }

// sourcery:inline:auto:StructType.Init
init(keyword: Pos, directives: Set<TypeDirective>, lbrace: Pos, fields: [StructField], rbrace: Pos, type: Type = ty.invalid, checked: Checked = .invalid) {
    self.keyword = keyword
    self.directives = directives
    self.lbrace = lbrace
    self.fields = fields
    self.rbrace = rbrace
    self.type = type
    self.checked = checked
}
// sourcery:end
}

class PolyStructType: Node, Expr {
    var lbrace: Pos
    var polyTypes: PolyParameterList
    var fields: [StructField]
    var rbrace: Pos

    var type: Type = ty.invalid

    var start: Pos { return polyTypes.start }
    var end: Pos { return rbrace }

// sourcery:inline:auto:PolyStructType.Init
init(lbrace: Pos, polyTypes: PolyParameterList, fields: [StructField], rbrace: Pos, type: Type = ty.invalid) {
    self.lbrace = lbrace
    self.polyTypes = polyTypes
    self.fields = fields
    self.rbrace = rbrace
    self.type = type
}
// sourcery:end
}

class EnumType: Node, Expr {
    var keyword: Pos
    var explicitType: Expr?
    var flagsDirective: Pos?
    var cases: [EnumCase]
    var rbrace: Pos

    var type: Type = ty.invalid

    var start: Pos { return keyword }
    var end: Pos { return rbrace }

    var isFlags: Bool { return flagsDirective != nil }

// sourcery:inline:auto:EnumType.Init
init(keyword: Pos, explicitType: Expr?, flagsDirective: Pos?, cases: [EnumCase], rbrace: Pos, type: Type = ty.invalid) {
    self.keyword = keyword
    self.explicitType = explicitType
    self.flagsDirective = flagsDirective
    self.cases = cases
    self.rbrace = rbrace
    self.type = type
}
// sourcery:end
}

class UnionType: Node, Expr {
    var keyword: Pos
    var directives: Set<TypeDirective>
    var lbrace: Pos
    var tag: StructField?
    var fields: [StructField] // TODO: Switch to `UnionField` so we can provide customizations specific to union members
    var rbrace: Pos

    var type: Type = ty.invalid

    var start: Pos { return keyword }
    var end: Pos { return rbrace }

// sourcery:inline:auto:UnionType.Init
init(keyword: Pos, directives: Set<TypeDirective>, lbrace: Pos, tag: StructField?, fields: [StructField], rbrace: Pos, type: Type = ty.invalid) {
    self.keyword = keyword
    self.directives = directives
    self.lbrace = lbrace
    self.tag = tag
    self.fields = fields
    self.rbrace = rbrace
    self.type = type
}
// sourcery:end
}

class PolyType: Node, Expr {
    var dollar: Pos
    var explicitType: Expr

    var type: Type = ty.invalid

    var start: Pos { return dollar }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:PolyType.Init
init(dollar: Pos, explicitType: Expr, type: Type = ty.invalid) {
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

    var type: Type = ty.invalid

    var start: Pos { return ellipsis }
    var end: Pos { return explicitType.end }

// sourcery:inline:auto:VariadicType.Init
init(ellipsis: Pos, explicitType: Expr, isCvargs: Bool, type: Type = ty.invalid) {
    self.ellipsis = ellipsis
    self.explicitType = explicitType
    self.isCvargs = isCvargs
    self.type = type
}
// sourcery:end
}

class FuncType: Node, Expr {
    var lparen: Pos
    var labels: [Ident]?
    var params: [Expr]
    var results: [Expr]
    var flags: FunctionFlags

    var type: Type = ty.invalid

    var start: Pos { return lparen }
    var end: Pos { return results.last!.end }

// sourcery:inline:auto:FuncType.Init
init(lparen: Pos, labels: [Ident]?, params: [Expr], results: [Expr], flags: FunctionFlags, type: Type = ty.invalid) {
    self.lparen = lparen
    self.labels = labels
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

class Defer: Node, Stmt {
    var keyword: Pos
    var stmt: Stmt

    var start: Pos { return keyword }
    var end: Pos { return stmt.end }

// sourcery:inline:auto:Defer.Init
init(keyword: Pos, stmt: Stmt) {
    self.keyword = keyword
    self.stmt = stmt
}
// sourcery:end
}

class Using: Node, Stmt, TopLevelStmt {
    var keyword: Pos
    var expr: Expr

    var start: Pos { return keyword }
    var end: Pos { return expr.end }

// sourcery:inline:auto:Using.Init
init(keyword: Pos, expr: Expr) {
    self.keyword = keyword
    self.expr = expr
}
// sourcery:end
}

class Branch: Node, Stmt {
    /// Keyword Token (break, continue, fallthrough)
    var start: Pos
    var token: Token
    var label: Ident?

    var target: Entity! = nil

    var end: Pos { return label?.end ?? (start + token.description.count) }

// sourcery:inline:auto:Branch.Init
init(start: Pos, token: Token, label: Ident?, target: Entity! = nil) {
    self.start = start
    self.token = token
    self.label = label
    self.target = target
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
    var match: [Expr]
    var colon: Pos
    var block: Block

    var label: Entity! = nil
    var binding: Entity? = nil

    var start: Pos { return keyword }
    var end: Pos { return block.end }

// sourcery:inline:auto:CaseClause.Init
init(keyword: Pos, match: [Expr], colon: Pos, block: Block, label: Entity! = nil, binding: Entity? = nil) {
    self.keyword = keyword
    self.match = match
    self.colon = colon
    self.block = block
    self.label = label
    self.binding = binding
}
// sourcery:end
}

class Switch: Node, Stmt {
    var keyword: Pos
    var match: Expr?
    var binding: Ident?
    var cases: [CaseClause]
    var rbrace: Pos

    var flags: Flags

    var label: Entity! = nil

    var start: Pos { return keyword }
    var end: Pos { return rbrace }

    struct Flags: OptionSet {
        let rawValue: UInt8

        static let none  = Flags(rawValue: 0b0000)
        static let using = Flags(rawValue: 0b0001)
        static let type  = Flags(rawValue: 0b0010)
        static let any   = Flags(rawValue: 0b0100)
        static let union = Flags(rawValue: 0b1000)
        // NOTE: The last three are basically exclusive
    }

// sourcery:inline:auto:Switch.Init
init(keyword: Pos, match: Expr?, binding: Ident?, cases: [CaseClause], rbrace: Pos, flags: Flags, label: Entity! = nil) {
    self.keyword = keyword
    self.match = match
    self.binding = binding
    self.cases = cases
    self.rbrace = rbrace
    self.flags = flags
    self.label = label
}
// sourcery:end
}

class For: Node, Stmt {
    var keyword: Pos
    var initializer: Stmt?
    var cond: Expr?
    var step: Stmt?
    var body: Block

    var breakLabel: Entity! = nil
    var continueLabel: Entity! = nil

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:For.Init
init(keyword: Pos, initializer: Stmt?, cond: Expr?, step: Stmt?, body: Block, breakLabel: Entity! = nil, continueLabel: Entity! = nil) {
    self.keyword = keyword
    self.initializer = initializer
    self.cond = cond
    self.step = step
    self.body = body
    self.breakLabel = breakLabel
    self.continueLabel = continueLabel
}
// sourcery:end
}

class ForIn: Node, Stmt {
    var keyword: Pos
    var names: [Ident]
    var aggregate: Expr
    var body: Block

    var breakLabel: Entity! = nil
    var continueLabel: Entity! = nil
    var element: Entity! = nil
    var index: Entity? = nil
    var checked: Checked = .invalid

    enum Checked {
        case invalid
        case array(Int)
        case slice
        case enumeration
    }

    var start: Pos { return keyword }
    var end: Pos { return body.end }

// sourcery:inline:auto:ForIn.Init
init(keyword: Pos, names: [Ident], aggregate: Expr, body: Block, breakLabel: Entity! = nil, continueLabel: Entity! = nil, element: Entity! = nil, index: Entity? = nil, checked: Checked = .invalid) {
    self.keyword = keyword
    self.names = names
    self.aggregate = aggregate
    self.body = body
    self.breakLabel = breakLabel
    self.continueLabel = continueLabel
    self.element = element
    self.index = index
    self.checked = checked
}
// sourcery:end
}

// MARK: Declarations

class Import: Node, TopLevelStmt {
    var directive: Pos
    var alias: Ident?
    var path: Expr
    var importSymbolsIntoScope: Bool
    var exportSymbolsOutOfScope: Bool

    var resolvedName: String? = nil
    var scope: Scope! = nil
    var importee: Importable! = nil

    var start: Pos { return directive }
    var end: Pos { return alias?.end ?? path.end }

// sourcery:inline:auto:Import.Init
init(directive: Pos, alias: Ident?, path: Expr, importSymbolsIntoScope: Bool, exportSymbolsOutOfScope: Bool, resolvedName: String? = nil, scope: Scope! = nil, importee: Importable! = nil) {
    self.directive = directive
    self.alias = alias
    self.path = path
    self.importSymbolsIntoScope = importSymbolsIntoScope
    self.exportSymbolsOutOfScope = exportSymbolsOutOfScope
    self.resolvedName = resolvedName
    self.scope = scope
    self.importee = importee
}
// sourcery:end
}

class Library: Node, TopLevelStmt {
    var directive: Pos
    var path: Expr
    var alias: Ident?

    var resolvedName: String? = nil

    var start: Pos { return directive }
    var end: Pos { return alias?.end ?? path.end }

// sourcery:inline:auto:Library.Init
init(directive: Pos, path: Expr, alias: Ident?, resolvedName: String? = nil) {
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

    var linkname: String? = nil
    var callconv: String? = nil

    var dependsOn: Set<Entity> = []
    var emitted: Bool = false

    var start: Pos { return directive }
    var end: Pos { return decl.end }

// sourcery:inline:auto:Foreign.Init
init(directive: Pos, library: Ident, decl: Decl, linkname: String? = nil, callconv: String? = nil, dependsOn: Set<Entity> = [], emitted: Bool = false) {
    self.directive = directive
    self.library = library
    self.decl = decl
    self.linkname = linkname
    self.callconv = callconv
    self.dependsOn = dependsOn
    self.emitted = emitted
}
// sourcery:end
}

class DeclBlock: Node, TopLevelStmt, CallConvApplicable {
    var lbrace: Pos
    var decls: [Declaration]
    var rbrace: Pos

    var isForeign: Bool

    var linkprefix: String? = nil
    var callconv: String? = nil

    var dependsOn: Set<Entity> = []
    var emitted: Bool = false

    var start: Pos { return lbrace }
    var end: Pos { return rbrace }

// sourcery:inline:auto:DeclBlock.Init
init(lbrace: Pos, decls: [Declaration], rbrace: Pos, isForeign: Bool, linkprefix: String? = nil, callconv: String? = nil, dependsOn: Set<Entity> = [], emitted: Bool = false) {
    self.lbrace = lbrace
    self.decls = decls
    self.rbrace = rbrace
    self.isForeign = isForeign
    self.linkprefix = linkprefix
    self.callconv = callconv
    self.dependsOn = dependsOn
    self.emitted = emitted
}
// sourcery:end
}

class Declaration: Node, TopLevelStmt, Decl, LinknameApplicable, CallConvApplicable, TestApplicable {

    var names: [Ident]
    var explicitType: Expr?
    var values: [Expr]

    var isConstant: Bool

    var callconv: String? = nil
    var linkname: String? = nil
    var isTest: Bool = false

    var entities: [Entity]! = nil
    var dependsOn: Set<Entity> = []
    var declaringScope: Scope? = nil
    var checked: Bool = false
    var emitted: Bool = false

    var start: Pos { return names.first!.start }
    var end: Pos { return values.first?.end ?? names.last!.start }

// sourcery:inline:auto:Declaration.Init
init(names: [Ident], explicitType: Expr?, values: [Expr], isConstant: Bool, callconv: String? = nil, linkname: String? = nil, isTest: Bool = false, entities: [Entity]! = nil, dependsOn: Set<Entity> = [], declaringScope: Scope? = nil, checked: Bool = false, emitted: Bool = false) {
    self.names = names
    self.explicitType = explicitType
    self.values = values
    self.isConstant = isConstant
    self.callconv = callconv
    self.linkname = linkname
    self.isTest = isTest
    self.entities = entities
    self.dependsOn = dependsOn
    self.declaringScope = declaringScope
    self.checked = checked
    self.emitted = emitted
}
// sourcery:end
}

class BadDecl: Node, Decl {
    var start: Pos
    var end: Pos

    var dependsOn: Set<Entity> {
        get { return [] }
        set { }
    }
    var checked: Bool {
        get { return true }
        set { }
    }
    var emitted: Bool {
        get { return true }
        set { }
    }

// sourcery:inline:auto:BadDecl.Init
init(start: Pos, end: Pos) {
    self.start = start
    self.end = end
}
// sourcery:end
}

class InlineAsm: Node, Expr, Stmt {
    var directive: Pos
    var rparen: Pos
    var asm: BasicLit
    var constraints: BasicLit
    var arguments: [Expr]

    var type: Type = ty.invalid

    var start: Pos { return directive }
    var end: Pos { return directive }

// sourcery:inline:auto:InlineAsm.Init
init(directive: Pos, rparen: Pos, asm: BasicLit, constraints: BasicLit, arguments: [Expr], type: Type = ty.invalid) {
    self.directive = directive
    self.rparen = rparen
    self.asm = asm
    self.constraints = constraints
    self.arguments = arguments
    self.type = type
}
// sourcery:end
}

func isAddressOfExpr(_ e: Expr) -> Bool {
    return (e as? Unary)?.op == .and
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
    let file: SourceFile
    let specializedTypes: [Type]
    let strippedType: ty.Function
    let generatedFunctionNode: FuncLit
    var mangledName: String

// sourcery:inline:auto:FunctionSpecialization.Init
init(file: SourceFile, specializedTypes: [Type], strippedType: ty.Function, generatedFunctionNode: FuncLit, mangledName: String) {
    self.file = file
    self.specializedTypes = specializedTypes
    self.strippedType = strippedType
    self.generatedFunctionNode = generatedFunctionNode
    self.mangledName = mangledName
}
// sourcery:end
}

class StructSpecialization {
    let specializedTypes: [Type]
    let strippedType: ty.Struct
    let generatedStructNode: StructType

// sourcery:inline:auto:StructSpecialization.Init
init(specializedTypes: [Type], strippedType: ty.Struct, generatedStructNode: StructType) {
    self.specializedTypes = specializedTypes
    self.strippedType = strippedType
    self.generatedStructNode = generatedStructNode
}
// sourcery:end
}
