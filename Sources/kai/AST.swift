
import ByteHashable

class ASTFile {

    var lexer: Lexer
    var fullpath: String
    var name: String
    /// All of the top level declarations, statements and expressions are placed into this array
    var nodes: [AstNode]
    var scopeLevel: Int = 0
    var scope: Scope?       // NOTE: Created in checker

    var declInfo: DeclInfo? // NOTE: Created in checker

    var errors: Int = 0

    static var errorTolerance = 6

    init(named: String) {

        let file = File(path: named)!
        self.fullpath = file.path
        self.lexer = Lexer(file)
        self.name = named
        self.nodes = []
        self.scopeLevel = 0
        self.scope = nil
        self.declInfo = nil
        self.errors = 0
    }
}


// TODO(vdka): Convert all SourceLocations to SourceRanges
// TODO(vdka): Bring all locations to the top level nodes.
indirect enum AstNode {

    case invalid(SourceLocation)

    case ident(String, SourceLocation)
    case basicDirective(String, SourceLocation)

    /// - Parameter name: Name is what is followed by `:`
    case argument(label: AstNode?, value: AstNode, SourceLocation)

    /// - Parameter names: eg. (x, y, z: f32)
    case field(names: [AstNode], type: AstNode, SourceLocation)
    case fieldList([AstNode], SourceLocation)

    // TODO(vdka): Add a foreign source here. Variables can be foreign too.

    // TODO(vdka): enum's will also need to have another field type which stores values
    // indirect case fieldValue(name: AstNode, value: AstNode, SourceLocation)

    case literal(Literal)
    case expr(Expression)
    case stmt(Statement)
    case decl(Declaration)
    case type(Type)

    enum Literal {
        case basic(Basic, SourceLocation)
        case proc(ProcSource, type: AstNode, SourceLocation)
        case compound(type: AstNode, elements: [AstNode], SourceRange)

        enum Basic {
            case integer(Int64) // TODO(vdka): BigInt
            case float(Double) // TODO(vdka): BigFloat
            case string(String)
            // TODO(vdka): Maybe support runes '\u{12345}'
        }

        enum ProcSource {
            case native(body: AstNode)
            // TODO(vdka): This potentially needs changing
            /// - Parameter symbol: represents the symbol name to look for, it maybe the identifier name if omitted
            case foreign(lib: AstNode, symbol: AstNode)
        }
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

        // NOTE(vdka): If I want to be able to return a value from a scope it'll be an expr.
        case block(statements: [AstNode], SourceRange)
        case `if`(cond: AstNode, body: AstNode, AstNode?, SourceLocation)
        case `return`(results: [AstNode], SourceLocation)
        case `for`(initializer: AstNode, cond: AstNode, post: AstNode, body: AstNode, SourceLocation)
        case `case`(list: [AstNode], statements: [AstNode], SourceLocation)
        case control(ControlStatement, SourceLocation)
        case `defer`(statement: AstNode, SourceLocation)

        enum ControlStatement {
            case `break`
            case `continue`
            case `fallthrough`
        }
    }

    /// A declaration declares and binds something new into a scope
    enum Declaration {
        case bad(SourceRange)
        case value(isRuntime: Bool, names: [AstNode], type: AstNode?, values: [AstNode], SourceLocation)
        case `import`(relativePath: AstNode, fullPath: String, importName: AstNode?, SourceLocation)
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

extension AstNode: Hashable {

    var hashValue: Int {
        // Because Int is the platform native size, and so are pointers the result is
        //   that the hashValue should be the pointer address.
        // Thanks to this we have instance identity as the hashValue.
        return unsafeBitCast(self, to: Int.self)
    }
}
extension AstNode: ByteHashable {}

extension AstNode {

    var startLocation: SourceLocation {
        return location.lowerBound
    }

    var endLocation: SourceLocation {
        return location.upperBound
    }

    var location: SourceRange {

        switch self {
        case .invalid(let location),
             .ident(_, let location),
             .basicDirective(_, let location),
             .argument(_, value: _, let location),
             .field(names: _, type: _, let location),
             .fieldList(_, let location):

            return location ..< location

        case .literal(let literal):
            switch literal {
            case .basic(_, let location),
                 .proc(_, type: _, let location):

                return location ..< location

            case .compound(_, _, let range):
                return range
            }

        case let .expr(expr):
            switch expr {
            case .bad(let range):
                return range

            case .paren(_, let range):
                return range

            case .subscript(_, _, let range):
                return range

            case .call(_, _, let range):
                return range

            case .unary(_, _, let location),
                 .binary(_, _, _, let location),
                 .selector(_, _, let location),
                 .deref(_, let location),
                 .ternary(_, _, _, let location):

                return location ..< location

            }

        case .stmt(let stmt):
            switch stmt {
            case .bad(let range):
                return range

            case .block(_, let range):
                return range

            case .expr(let ast):
                return ast.location

            case .empty(let location),
                 .assign(_, _, _, let location),
                 .if(_, _, _, let location),
                 .return(_, let location),
                 .for(_, _, _, _, let location),
                 .case(_, _, let location),
                 .defer(_, let location),
                 .control(_, let location):

                return location ..< location
            }

        case .decl(let decl):
            switch decl {
            case .bad(let range):
                return range

            case .value(_, _, _, _, let location),
                 .import(_, _, _, let location),
                 .library(_, _, let location):

                return location ..< location
            }

        case .type(let type):
            switch type {
            case .helper(_, let location),
                 .proc(_, _, let location),
                 .pointer(_, let location),
                 .array(_, _, let location),
                 .dynArray(_, let location),
                 .struct(_, let location),
                 .enum(_, _, let location):

                return location ..< location
            }
        }
    }
}

extension AstNode {

    var isType: Bool {
        switch self {
        case .ident, .type:
            return true

        default:
            return false
        }
    }

    var isIdent: Bool {
        switch self {
        case .ident:
            return true

        default:
            return false
        }
    }

    var isDecl: Bool {
        switch self {
        case .decl:
            return true

        default:
            return false
        }
    }

    func unparenExpr() -> AstNode {
        var curr = self
        while case .expr(.paren(let expr, _)) = curr {
            curr = expr
        }

        return curr
    }
}

extension AstNode {

    var identifier: String {
        guard case .ident(let ident, _) = self else {
            preconditionFailure()
        }
        return ident
    }

    var literal: String {
        switch self {
        case .literal(let lit):
            switch lit {
            case .basic(let lit, _):
                switch lit {
                case .string(let str):
                    return "\"" + str + "\""

                case .integer(let int):
                    return int.description

                case .float(let dbl):
                    return dbl.description
                }

            case .proc(let procSource, let type, _):
                return "native " + type.typeDescription

            case .compound(let type, _, _):
                return "lit " + type.typeDescription
            }

        default:
            fatalError()
        }
    }

    var fieldListDescription: String {

        switch self {
        case .ident(let ident, _):
            return ident

        case .fieldList(let fields, _):

            let str = fields
                .map { (node: AstNode) -> String in
                    guard case .field(let names, let type, _) = node else {
                        fatalError()
                    }

                    return names.map({ $0.identifier }).joined(separator: ", ") + ": " + type.typeDescription
                }.joined(separator: ", ")

            return "(" + str + ")"

        default:
            fatalError()
        }
    }

    var typeDescription: String {
        switch self {
        case .type(let type):
            switch type {
            case .proc(let params, let results, _):
                return params.fieldListDescription + " -> " + results.fieldListDescription

            case .struct(_, _):
                return "struct"

            case .array(_, let baseType, _):
                return "[]" + baseType.typeDescription

            case .dynArray(let baseType, _):
                return "[..]" + baseType.typeDescription

            case .enum(_, _, _):
                return "enum"

            case .pointer(let baseType, _):
                return "*" + baseType.typeDescription

            case .helper(let type, _):
                return "alias of " + type.typeDescription
            }

        case .ident(let name, _):
            return name

        default:
            fatalError()
        }
    }

    // TODO(vdka): Print types nicely
    func pretty(depth: Int = 0, includeParens: Bool = true) -> String {

        var name: String
        var unlabeled: [String] = []
        var labeled: [String: String] = [:]

        var children: [AstNode] = []

        switch self {
        case .invalid(let location):
            name = "invalid"
            labeled["location"] = location.description

        case .ident(let ident, _):
            name = "ident"
            unlabeled.append(ident)

        case .basicDirective(let directive, _):
            name = "directive"
            unlabeled.append(directive)

        case .argument(_, let val, _):
            // TODO(vdka): print labels.
            name = "argument"
            unlabeled.append(val.pretty(depth: depth + 1, includeParens: true))

        case .field(let names, _, _):
            name = "field"
            //            labeled["type"] = type.pretty(depth: depth + 1)
            children.append(contentsOf: names)

        case .fieldList(_, _):
            name = "fields"

        case .literal(let literal):
            switch literal {
            case .basic(_, _):
                name = "lit"
                unlabeled.append(self.literal)

            case .proc(let procSource, let type, _):
                name = "proc"
                labeled["type"] = type.typeDescription

                // TODO(vdka): work out how to nicely _stringify_ a node
                switch procSource {
                case .native(let body):
                    children.append(body)

                case .foreign(_, _):
                    break
                }

            case .compound(_, _, _):
                name = "compoundLit"
                //                labeled["type"] = type.desc
            }

        case .expr(let expr):
            switch expr {
            case .bad(let range):
                name = "badExpr"
                unlabeled.append(range.description)

            case .unary(let op, let expr, _):
                name = "unaryExpr"
                unlabeled.append(op)
                children.append(expr)

            case .binary(let op, let lhs, let rhs, _):
                name = "binaryExpr"
                unlabeled.append(op)
                children.append(lhs)
                children.append(rhs)

            case .paren(let expr, _):
                name = "parenExpr"
                children.append(expr)

            case .selector(let receiver, let selector, _):
                name = "selectorExpr"
                children.append(receiver)
                children.append(selector)

            case .subscript(let receiver, let index, _):
                name = "subscriptExpr"
                children.append(receiver)
                children.append(index)

            case .deref(let receiver, _):
                name = "dereferenceExpr"
                children.append(receiver)

            case .call(let receiver, let args, _):
                name = "callExpr"
                children.append(receiver)
                children.append(contentsOf: args)

            case .ternary(let cond, let trueBranch, let falseBranch, _):
                name = "ternaryExpr"
                children.append(cond)
                children.append(trueBranch)
                children.append(falseBranch)
            }

        case .stmt(let stmt):
            switch stmt {
            case .bad(let range):
                name = "badStmt"
                unlabeled.append(range.description)

            case .empty(_):
                name = "emptyStmt"

            case .expr(let ast):
                name = ast.pretty(depth: depth + 1)

            case .assign(let op, let lhs, let rhs, _):
                name = "assignmentStmt"
                unlabeled.append(op)
                children.append(contentsOf: lhs)
                children.append(contentsOf: rhs)

            case .block(let stmts, _):
                name = "blockStmt"
                children.append(contentsOf: stmts)

            case .if(let cond, let trueBranch, let falseBranch, _):
                name = "ifStmt"
                children.append(cond)
                children.append(trueBranch)
                if let falseBranch = falseBranch {
                    children.append(falseBranch)
                }

            case .return(let results, _):
                name = "returnStmt"
                children.append(contentsOf: results)

            case .for(let initializer, let cond, let post, let body, _):
                name = "forStmt"
                children.append(initializer)
                children.append(cond)
                children.append(post)
                children.append(body)

            case .case(let list, let stmts, _):
                name = "caseStmt"
                children.append(contentsOf: list)
                children.append(contentsOf: stmts)

            case .defer(let stmt, _):
                name = "deferStmt"
                children.append(stmt)

            case .control(let controlStatement, _):
                name = String(describing: controlStatement)
            }

        case .decl(let decl):
            switch decl {
            case .bad(let range):
                name = "badDecl"
                unlabeled.append(range.description)

            case .value(_, let names, _, let values, _):
                name = "decl"
                //                labeled["type"] = type?.pretty(depth: depth + 1) ?? "<infered>"
                unlabeled.append(names.first!.identifier)
                children.append(contentsOf: values)

            case .import(let relPath, let fullPath, let importName, _):
                name = "importDecl"
                //                labeled["relPath"] = relPath
                labeled["fullPath"] = fullPath
                //                labeled["name"] = importName

            case .library(let filePath, let libName, _):
                name = "libraryDecl"
                labeled["filePath"] = filePath
                labeled["libName"] = libName
            }

        case .type(let type):
            switch type {
            case .helper(_, _):
                name = "helperType"
                //                labeled["type"] = type.pretty(depth: depth + 1)

            case .proc(let params, let results, _):
                name = "procType"
                labeled["params"] = params.pretty(depth: depth + 1)
                labeled["results"] = results.pretty(depth: depth + 1)

            case .pointer(let type, _):
                name = "pointerType"
                labeled["baseType"] = type.pretty(depth: depth + 1)

            case .array(let count, let baseType, _):
                name = "arrayType"
                labeled["size"] = count.pretty()
                labeled["baseType"] = baseType.pretty()
                // FIXME: These should be inline serialized (return directly?)

            case .dynArray(let baseType, _):
                name = "arrayType"
                labeled["size"] = "dynamic"
                labeled["baseType"] = baseType.pretty()
                // FIXME: These should be inline serialized

            case .struct(let fields, _):
                name = "structType"
                children.append(contentsOf: fields)

            case .enum(let baseType, let fields, _):
                name = "enumType"
                labeled["baseType"] = baseType.pretty(depth: depth + 1)
                children.append(contentsOf: fields)
            }
        }

        let indent = (0...depth).reduce("\n", { $0.0 + "  " })
        var str = indent

        if includeParens {
            str.append("(")
        }

        str.append(name)
        str.append(unlabeled.reduce("", { [$0.0, " ", $0.1].joined() }))
        str.append(labeled.reduce("", { [$0.0, " ", $0.1.key, ":'", $0.1.value, "'"].joined() }))

        children.map({ $0.pretty(depth: depth + 1, includeParens: true) }).forEach({ str.append($0) })

        if includeParens {
            str.append(")")
        }

        return str
    }
}

extension ASTFile {

    func pretty() -> String {
        var description = "("
        for node in nodes {
            description += node.pretty(depth: 1)
        }
        description += ")"

        return description
    }
}
