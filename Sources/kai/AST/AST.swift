
import ByteHashable

class ASTFile {

    var lexer: Lexer
    var name: String
    /// All of the top level declarations, statements and expressions are placed into this array
    var nodes: [AstNode]
    var scopeLevel: Int = 0
    var scope: Scope?       // NOTE: Created in checker

    // FIXME: I need one of these for each `decl`
    var declInfo: DeclInfo? // NOTE: Created in checker

    var errors: Int = 0

    static var errorTolerance = 6

    init(named: String) {

        let file = File(path: named)!
        self.lexer = Lexer(file)
        self.name = named
        self.nodes = []
        self.scopeLevel = 0
        self.scope = nil
        self.declInfo = nil
        self.errors = 0
    }
}

enum AstNode {

    case ident(String, SourceLocation)
    case directive(String, SourceLocation)

    indirect case literal(Literal)
    indirect case expr(Expression)
    indirect case stmt(Statement)
    indirect case decl(Declaration)
    indirect case type(`Type`)

    // TODO(vdka): Odin has another kind of field node.
    /// - Parameter names: eg. (x, y, z: f32) -> f32
    indirect case field(names: [AstNode], type: AstNode, SourceLocation)

    indirect case fieldList([AstNode], SourceLocation)

    enum Literal {
        enum ProcSource {
            case native(body: AstNode)
            // TODO(vdka): This potentially needs changing
            case foreign(lib: AstNode, name: String, linkName: String)
        }

        case basic(String, SourceLocation)
        case proc(ProcSource, type: AstNode, SourceLocation)
        case compound(type: AstNode, elements: [AstNode], SourceRange)
    }

    /// Expressions resolve to a resulting value
    enum Expression {
        case bad(SourceRange)
        case unary(op: String, expr: AstNode, SourceLocation)
        case binary(op: String, lhs: AstNode, rhs: AstNode, SourceLocation)
        case paren(expr: AstNode, SourceRange)
        case selector(receiver: AstNode, selector: AstNode, SourceLocation)
        case `subscript`(receiver: AstNode, index: AstNode, SourceRange)
        case deref(receiver: AstNode, SourceLocation)
        case call(receiver: AstNode, args: [AstNode], SourceRange)
        case ternary(cond: AstNode, AstNode, AstNode, SourceLocation)
    }

    /// Statements do not resolve to an value
    enum Statement {
        case bad(SourceRange)
        case empty(SourceLocation)
        /// An expr whose return value we dispose of
        case expr(AstNode)
        case assign(op: String, lhs: [AstNode], rhs: [AstNode], SourceLocation)
        case block(statements: [AstNode], SourceRange)
        case `if`(cond: AstNode, body: AstNode, AstNode?, SourceLocation)
        case `return`(results: [AstNode], SourceLocation)
        case `for`(initializer: AstNode, cond: AstNode, post: AstNode, body: AstNode, SourceLocation)
        case `case`(list: [AstNode], statements: [AstNode], SourceLocation)
        case `defer`(statement: AstNode, SourceLocation)
    }

    /// A declaration declares and binds something new into a scope
    enum Declaration {
        case bad(SourceRange)
        case value(isVar: Bool, names: [AstNode], type: AstNode?, values: [AstNode], SourceLocation)
        case `import`(relativePath: String, fullPath: String, importName: String, SourceLocation)
        case library(filePath: String, libName: String, SourceLocation)
    }

    enum `Type` {
        case helper(type: AstNode, SourceLocation)
        case proc(params: AstNode, results: AstNode, SourceLocation)
        case pointer(baseType: AstNode, SourceLocation)
        case array(count: AstNode, baseType: AstNode, SourceLocation)
        case dynArray(baseType: AstNode, SourceLocation)
        case `struct`(fields: [AstNode], SourceLocation)
        case `enum`(baseType: AstNode, fields: [AstNode], SourceLocation) // fields are `.field`
    }
}

extension AstNode: Equatable {
    static func == (lhs: AstNode, rhs: AstNode) -> Bool {
        switch (lhs, rhs) {
            default:
                return isMemoryEquivalent(lhs, rhs)
        }
    }
}

extension AstNode: ByteHashable {}

extension AstNode {

    var location: SourceRange {

        switch self {
        case .ident(_, let location):
            return location ..< location

        case .directive(_, let location):
            return location ..< location

        case .literal(let literal):
            switch literal {
            case .basic(_, let location):
                return location ..< location

            case .proc(_, type: _, let location):
                return location ..< location

            case .compound(type: _, elements: _, let range):
                return range
            }

        case let .expr(expr):
            switch expr {
            case .bad(let range):
                return range

            case .unary(op: _, expr: _, let location):
                return location ..< location

            case .binary(op: _, lhs: _, rhs: _, let location):
                return location ..< location

            case .paren(expr: _, let range):
                return range

            case .selector(receiver: _, selector: _, let location):
                return location ..< location

            case .subscript(receiver: _, index: _, let range):
                return range

            case .deref(receiver: _, let location):
                return location ..< location

            case .call(receiver: _, args: _, let range):
                return range

            case .ternary(cond: _, _, _, let location):
                return location ..< location

            }

        case .stmt(let stmt):
            switch stmt {
            case .bad(let range):
                return range

            case .empty(let location):
                return location ..< location

            case .expr(let ast):
                return ast.location

            case .assign(op: _, lhs: _, rhs: _, let location):
                return location ..< location

            case .block(statements: _, let range):
                return range

            case .if(cond: _, body: _, _, let location):
                return location ..< location

            case .return(results: _, let location):
                return location ..< location

            case .for(initializer: _, cond: _, post: _, body: _, let location):
                return location ..< location

            case .case(list: _, statements: _, let location):
                return location ..< location

            case .defer(statement: _, let location):
                return location ..< location
            }

        case .decl(let decl):
            switch decl {
            case .bad(let range):
                return range

            case .value(isVar: _, names: _, type: _, values: _, let location):
                return location ..< location

            case .import(relativePath: _, fullPath: _, importName: _, let location):
                return location ..< location

            case .library(filePath: _, libName: _, let location):
                return location ..< location
            }

        case .type(let type):
            switch type {
            case .helper(type: _, let location):
                return location ..< location

            case .proc(params: _, results: _, let location):
                return location ..< location

            case .pointer(baseType: _, let location):
                return location ..< location

            case .array(count: _, baseType: _, let location):
                return location ..< location

            case .dynArray(baseType: _, let location):
                return location ..< location

            case .struct(fields: _, let location):
                return location ..< location

            case .enum(baseType: _, fields: _, let location):
                return location ..< location
            }

        case .field(names: _, type: _, let location):
            return location ..< location

        case .fieldList(_, let location):
            return location ..< location
        }
    }
}
