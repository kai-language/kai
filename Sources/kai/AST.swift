
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

indirect enum AstNode {

    case invalid(SourceRange)

    case ident(String, SourceRange)
    case directive(String, args: [AstNode], SourceRange)

    case field(name: AstNode, type: AstNode, SourceRange)
    case list([AstNode], SourceRange)

    case litInteger(Int64, SourceRange)
    case litFloat(Double, SourceRange)
    case litString(String, SourceRange)

    /// - Parameter type: `typeProc` node
    /// - Note: `type` holds reference to the args
    case litProc(type: AstNode, body: AstNode, SourceRange)



    case declValue(isRuntime: Bool, names: [AstNode], type: AstNode?, values: [AstNode], SourceRange)
    case declImport(path: AstNode, fullpath: String?, importName: AstNode?, SourceRange)
    case declLibrary(path: AstNode, libName: AstNode, SourceRange)

    case exprUnary(String, expr: AstNode, SourceRange)
    case exprBinary(String, lhs: AstNode, rhs: AstNode, SourceRange)
    case exprParen(AstNode, SourceRange)
    case exprSelector(receiver: AstNode, member: AstNode, SourceRange)

    /// - Parameter args: an array of `arg` nodes
    case exprCall(receiver: AstNode, args: [AstNode], SourceRange)
    case exprTernary(cond: AstNode, AstNode, AstNode, SourceRange)



    /// Essentially an expr which has it's rvalue thrown away
    case stmtExpr(AstNode)
    case stmtEmpty(SourceRange)
    case stmtAssign(String, lhs: [AstNode], rhs: [AstNode], SourceRange)
    case stmtBlock([AstNode], SourceRange)
    case stmtIf(cond: AstNode, body: AstNode, AstNode?, SourceRange)
    case stmtReturn([AstNode], SourceRange)
    case stmtFor(initializer: AstNode, cond: AstNode, post: AstNode, body: AstNode, SourceRange)
    case stmtCase(list: [AstNode], statements: [AstNode], SourceRange)
    case stmtDefer(AstNode, SourceRange)
    case stmtBreak(SourceRange)
    case stmtContinue(SourceRange)
    case stmtFallthrough(SourceRange)

    /// - Parameter params:
    case typeProc(params: AstNode, results: AstNode, SourceRange)
    case typeArray(count: AstNode, baseType: AstNode, SourceRange)
    case typeStruct(fields: [AstNode], SourceRange)
    case typeEnum(baseType: AstNode, fields: [AstNode], SourceRange)
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
             .directive(_, _, let location),
             .list(_, let location),
             .field(_, _, let location),
             .litInteger(_, let location),
             .litFloat(_, let location),
             .litString(_, let location),
             .litProc(_, _, let location),
             .declValue(_, _, _, _, let location),
             .declImport(_, _, _, let location),
             .declLibrary(_, _, let location),
             .exprUnary(_, _, let location),
             .exprBinary(_, _, _, let location),
             .exprParen(_, let location),
             .exprSelector(_, _, let location),
             .exprCall(_, _, let location),
             .exprTernary(_, _, _, let location),
             .stmtEmpty(let location),
             .stmtAssign(_, _, _, let location),
             .stmtBlock(_, let location),
             .stmtIf(_, _, _, let location),
             .stmtReturn(_, let location),
             .stmtFor(_, _, _, _, let location),
             .stmtCase(_, _, let location),
             .stmtDefer(_, let location),
             .stmtBreak(let location),
             .stmtContinue(let location),
             .stmtFallthrough(let location),
             .typeProc(_, _, let location),
             .typeArray(_, _, let location),
             .typeStruct(_, let location),
             .typeEnum(_, _, let location):

             return location

        case .stmtExpr(let expr):
            return expr.location
        }
    }
}

extension AstNode {

    // NOTE(vdka): Ident can be a type too.
    var isType: Bool {
        switch self {
        case .typeProc, .typeArray, .typeStruct, .typeEnum:
            return true

        default:
            return false
        }
    }

    var isImport: Bool {
        switch self {
        case .declImport:
            return true

        default:
            return false
        }
    }

    var isLibrary: Bool {
        switch self {
        case .declLibrary:
            return true

        default:
            return false
        }
    }

    var isProcLit: Bool {
        switch self {
        case .litProc:
            return true

        default:
            return false
        }
    }

    var isField: Bool {
        switch self {
        case .field:
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
        case .declValue, .declImport, .declLibrary:
            return true

        default:
            return false
        }
    }

    func unparenExpr() -> AstNode {
        var curr = self
        while case .exprParen(let expr, _) = curr {
            curr = expr
        }

        return curr
    }

    /// Expands any list or non list nodes into [AstNode]
    func explode() -> [AstNode] {

        switch self {
        case .list(let vals, _):
            return vals

        default:
            return [self]
        }
    }
}


// MARK: - Printing

extension AstNode {

    var identifier: String {
        guard case .ident(let ident, _) = self else {
            preconditionFailure()
        }
        return ident
    }

    var value: String {

        switch self {
        case .ident(let s, _):
            return s

        case .litInteger(let i, _):
            return "'" + i.description + "'"

        case .litString(let s, _):
            return "\"" + s + "\""

        case .litFloat(let f, _):
            return "'" + f.description + "'"

        case .field(name: let name, type: let type, _):
            return name.value + ": " + type.value

        case .list:
            return self.listDescription

        case .exprSelector(let receiver, let member, _):
            return receiver.value + "." + member.value

        // TODO(vdka): There are a number of other cases which may want to be represented literally (as they were in the source)
        // below are a selection of those.
        /*
        case .exprParen:
        */

        default:
            dump(self)
            fatalError()
        }
    }

    var listDescription: String {

        switch self {
        case .ident(let ident, _):
            return ident

        case .list(let nodes, _):

            let str = nodes.map({ $0.value }).joined(separator: ", ")

            return "(" + str + ")"

        default:
            fatalError()
        }
    }

    var typeDescription: String {

        switch self {
        case .ident(let name, _):
            return name

        case .typeProc(let params, let results, _):
            return params.listDescription + " -> " + results.value

        case .typeStruct:
            return "struct"

        case .typeEnum:
            return "enum"

        case .typeArray(_, let baseType, _):
            return "[]" + baseType.typeDescription

        default:
            fatalError()
        }
    }

    var shortName: String {

        switch self {
        case .invalid: return "invalid"
        case .ident: return "ident"
        case .directive: return "directive"
        case .field: return "field"
        case .list: return "list"
        case .litInteger: return "litInteger"
        case .litFloat: return "litFloat"
        case .litString: return "litString"
        case .litProc: return "litProc"
        case .declValue(let decl): return decl.isRuntime ? "declRt" : "declCt"
        case .declImport: return "declImport"
        case .declLibrary: return "declLibrary"
        case .exprUnary: return "exprUnary"
        case .exprBinary: return "exprBinary"
        case .exprParen: return "exprParen"
        case .exprSelector: return "exprSelector"
        case .exprCall: return "exprCall"
        case .exprTernary: return "exprTernary"
        case .stmtEmpty: return "stmtEmpty"
        case .stmtAssign: return "stmtAssign"
        case .stmtBlock: return "stmtBlock"
        case .stmtIf: return "stmtIf"
        case .stmtReturn: return "stmtReturn"
        case .stmtFor: return "stmtFor"
        case .stmtCase: return "stmtCase"
        case .stmtDefer: return "stmtDefer"
        case .stmtBreak: return "stmtBreak"
        case .stmtContinue: return "stmtContinue"
        case .stmtFallthrough: return "stmtFallthrough"
        case .typeProc: return "typeProc"
        case .typeArray: return "typeArray"
        case .typeStruct: return "typeStruct"
        case .typeEnum: return "typeEnum"
        case .stmtExpr: return "stmtExpr"
        }
    }

    // TODO(vdka): Print types nicely
    func pretty(depth: Int = 0, includeParens: Bool = true) -> String {

        var unlabeled: [String] = []
        var labeled: [String: String] = [:]

        var children: [AstNode] = []

        switch self {
        case .invalid(let location):
            labeled["location"] = location.description

        case .ident(let ident, _):
            unlabeled.append(ident)

        case .directive(let directive, _, _):
            unlabeled.append(directive)

        case .field(let name, _, _):
            children.append(name)

        case .list(let nodes, _):
            children.append(contentsOf: nodes)
            break

        case .litInteger(let val, _):
            unlabeled.append("'" + val.description + "'")

        case .litFloat(let val, _):
            unlabeled.append("'" + val.description + "'")

        case .litString(let val, _):
            unlabeled.append("\"" + val + "\"")

        case .litProc(let type, let body, _):
//            labeled["type"] = type.typeDescription
            children.append(type)
            children.append(body)

        case .exprUnary(let op, let expr, _):
            unlabeled.append(op)
            children.append(expr)

        case .exprBinary(let op, let lhs, let rhs, _):
            unlabeled.append(op)
            children.append(lhs)
            children.append(rhs)

        case .exprParen(let expr, _):
            children.append(expr)

        case .exprSelector(let receiver, let selector, _):
            children.append(receiver)
            children.append(selector)

        case .exprCall(let receiver, let args, _):
            unlabeled.append(receiver.value)
            children.append(contentsOf: args)

        case .exprTernary(let cond, let trueBranch, let falseBranch, _):
            children.append(cond)
            children.append(trueBranch)
            children.append(falseBranch)

        case .stmtEmpty(_):
            break

        case .stmtExpr(let ast):
            children.append(ast)

        case .stmtAssign(let op, let lhs, let rhs, _):
            unlabeled.append(op)
            children.append(contentsOf: lhs)
            children.append(contentsOf: rhs)

        case .stmtBlock(let stmts, _):
            children.append(contentsOf: stmts)

        case .stmtIf(let cond, let trueBranch, let falseBranch, _):
            children.append(cond)
            children.append(trueBranch)
            if let falseBranch = falseBranch {
                children.append(falseBranch)
            }

        case .stmtReturn(let results, _):
            children.append(contentsOf: results)

        case .stmtFor(let initializer, let cond, let post, let body, _):
            children.append(initializer)
            children.append(cond)
            children.append(post)
            children.append(body)

        case .stmtCase(let list, let stmts, _):
            children.append(contentsOf: list)
            children.append(contentsOf: stmts)

        case .stmtDefer(let stmt, _):
            children.append(stmt)

        case .stmtBreak, .stmtContinue, .stmtFallthrough:
            break

        case .declValue(_, let names, _, let values, _):
            names.forEach({ unlabeled.append($0.value) })
            values.forEach({ children.append($0) })

        case .declImport(let path, _, importName: let importName, _):
            unlabeled.append(path.value)
            if let importName = importName {
                labeled["as"] = importName.value
            } else if case .litString(let pathString, _) = path {
                labeled["as"] = Checker.pathToEntityName(pathString)
            }

        case .declLibrary(let path, let libName, _):
            unlabeled.append(path.value)
            labeled["as"] = libName.value

        case .typeProc, .typeStruct, .typeEnum, .typeArray:
            unlabeled.append("'" + self.typeDescription + "'")
        }

        let indent = (0...depth).reduce("\n", { $0.0 + "  " })
        var str = indent

        if includeParens {
            str.append("(")
        }

        str.append(shortName.colored(.blue))
        str.append(unlabeled.reduce("", { [$0.0, " ", $0.1.colored(.red)].joined() }))
        str.append(labeled.reduce("", { [$0.0, " ", $0.1.key.colored(.white), ":'", $0.1.value.colored(.red), "'"].joined() }))

        children.map({ $0.pretty(depth: depth + 1, includeParens: true) }).forEach({ str.append($0) })

        if includeParens {
            str.append(")")
        }

        return str
    }
}

extension ASTFile {

    func pretty() -> String {
        var description = "(" + "file".colored(.blue) + "'" + fullpath.colored(.red) + "'"
        for node in nodes {
            description += node.pretty(depth: 1)
        }
        description += ")"

        return description
    }
}
