
import ByteHashable

class ASTFile {

    var lexer: Lexer
    var fullpath: String
    var name: String
    /// All of the top level declarations, statements and expressions are placed into this array
    var nodes: [AstNode] = []


    // NOTE: Created in checker

    var scope: Scope?
    var importedEntities: [Entity] = []

    var errors: Int = 0
    static var errorTolerance = 6

    init(named: String) {

        let file = File(path: named)!
        self.fullpath = file.path
        self.lexer = Lexer(file)
        self.name = named
        self.scope = nil
    }
}

indirect enum AstNode {

    case invalid(SourceRange)

    case list([AstNode], SourceRange)
    case comment(String, SourceRange)

    case ident(String, SourceRange)
    case directive(String, args: [AstNode], SourceRange)

    case ellipsis(AstNode, SourceRange)

    case litInteger(Int64, SourceRange)
    case litFloat(Double, SourceRange)
    case litString(String, SourceRange)

    /// - Parameter type: `typeProc` node
    /// - Note: `type` holds reference to the args
    case litProc(type: AstNode, body: AstNode, SourceRange)

    /// - Note: Used to represent array literals
    case litCompound(type: AstNode, elements: [AstNode], SourceRange)

    case litStruct(members: [AstNode], SourceRange)
    
    case litEnum(cases: [AstNode], SourceRange)

    case declValue(isRuntime: Bool, names: [AstNode], type: AstNode?, values: [AstNode], SourceRange)
    case declImport(path: AstNode, fullpath: String?, importName: AstNode?, SourceRange)
    case declLibrary(path: AstNode, fullpath: String?, libName: AstNode?, SourceRange)

    case exprSubscript(receiver: AstNode, value: AstNode, SourceRange)
    case exprCall(receiver: AstNode, args: [AstNode], SourceRange)
    case exprParen(AstNode, SourceRange)
    case exprDeref(AstNode, SourceRange)
    case exprUnary(Operator, expr: AstNode, SourceRange)
    case exprBinary(Operator, lhs: AstNode, rhs: AstNode, SourceRange)
    case exprTernary(cond: AstNode, AstNode, AstNode, SourceRange)
    case exprSelector(receiver: AstNode, member: AstNode, SourceRange)



    /// Essentially an expr which has it's rvalue thrown away
    case stmtExpr(AstNode)
    case stmtEmpty(SourceRange)
    case stmtAssign(AssignOperator, lhs: [AstNode], rhs: [AstNode], SourceRange)
    case stmtBlock([AstNode], SourceRange)
    case stmtIf(cond: AstNode, body: AstNode, AstNode?, SourceRange)
    case stmtReturn([AstNode], SourceRange)
    case stmtFor(initializer: AstNode?, cond: AstNode?, post: AstNode?, body: AstNode, SourceRange)
    case stmtSwitch(subject: AstNode?, cases: [AstNode], SourceRange)
    case stmtCase(AstNode?, body: AstNode, SourceRange)
    case stmtDefer(AstNode, SourceRange)
    case stmtBreak(SourceRange)
    case stmtContinue(SourceRange)

    /// - Parameter params:
    case typeProc(params: [AstNode], results: [AstNode], SourceRange)
    case typePointer(type: AstNode, SourceRange)
    case typeNullablePointer(type: AstNode, SourceRange)
    case typeArray(count: AstNode?, type: AstNode, SourceRange)
}

extension AstNode: Equatable {

    /// - Note: This is pointer equivalence
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
             .list(_, let location),
             .comment(_, let location),
             .ident(_, let location),
             .directive(_, _, let location),
             .ellipsis(_, let location),
             .litInteger(_, let location),
             .litFloat(_, let location),
             .litString(_, let location),
             .litProc(_, _, let location),
             .litCompound(_, _, let location),
             .litStruct(_, let location),
             .litEnum(_, let location),
             .declValue(_, _, _, _, let location),
             .declImport(_, _, _, let location),
             .declLibrary(_, _, _, let location),
             .exprParen(_, let location),
             .exprDeref(_, let location),
             .exprUnary(_, _, let location),
             .exprBinary(_, _, _, let location),
             .exprSelector(_, _, let location),
             .exprCall(_, _, let location),
             .exprSubscript(_, _, let location),
             .exprTernary(_, _, _, let location),
             .stmtEmpty(let location),
             .stmtAssign(_, _, _, let location),
             .stmtBlock(_, let location),
             .stmtIf(_, _, _, let location),
             .stmtReturn(_, let location),
             .stmtFor(_, _, _, _, let location),
             .stmtSwitch(_, _, let location),
             .stmtCase(_, _, let location),
             .stmtDefer(_, let location),
             .stmtBreak(let location),
             .stmtContinue(let location),
             .typeProc(_, _, let location),
             .typePointer(_, let location),
             .typeNullablePointer(_, let location),
             .typeArray(_, _, let location):

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
        case .typeProc:
            return true

        default:
            return false
        }
    }

    var isTypeArray: Bool {
        switch self {
        case .typeArray:
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

    var isLit: Bool {
        switch self {
        case .litFloat, .litString, .litInteger, .litProc:
            return true

        default:
            return false
        }
    }

    var isBasicLit: Bool {
        switch self {
        case .litFloat, .litInteger, .litString:
            return true

        default:
            return false
        }
    }

    var isCompoundLit: Bool {
        switch self {
        case .litCompound:
            return true

        default:
            return false
        }
    }

    var isNil: Bool {
        if case .ident("nil", _) = self {
            return true
        }
        return false
    }

    var isProcLit: Bool {
        switch self {
        case .litProc:
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

    var isDispose: Bool {
        if case .ident("_", _) = self {
            return true
        }
        return false
    }

    var isExpr: Bool {
        switch self {
        case .litInteger, .litFloat, .litString, .litProc, .litStruct, .litCompound:
            return true

        case .exprParen, .exprDeref,
             .exprUnary, .exprBinary, .exprTernary,
             .exprCall,
             .exprSelector, .exprSubscript:

            return true

        default:
            return false
        }
    }

    var isStmt: Bool {
        switch self {
        case .stmtBlock, .stmtEmpty, .stmtAssign,
             .stmtIf,
             .stmtFor,
             .stmtReturn, .stmtDefer,
             .stmtBreak, .stmtContinue:
            return true

        default:
            return false
        }
    }

    var isAssign: Bool {
        switch self {
        case .stmtAssign:
            return true
            
        default:
            return false
        }
    }
    
    var isDirective: Bool {
        if case .directive = self {
            return true
        }
        return false
    }

    var isDecl: Bool {
        switch self {
        case .declValue, .declImport, .declLibrary:
            return true

        default:
            return false
        }
    }
    
    var isComment: Bool {

        if case .comment = self {
            return true
        }
        return false
    }

    var isReturn: Bool {

        switch self {
        case .stmtReturn:
            return true

        default:
            return false
        }
    }

    var identifier: String {
        if case .ident(let ident, _) = self {
            return ident
        }
        
        panic()
    }

    /// - Note: Currently limited to stmt types that can return
    var children: [AstNode] {
        switch self {
        case .stmtBlock(let stmts, _):
            return stmts

        case .stmtBreak, .stmtEmpty, .stmtContinue, .stmtAssign:
            return []

        case .stmtIf(_, let bodyStmt, let elseStmt, _):
            return bodyStmt.children + (elseStmt?.children ?? [])

        case .stmtFor(_, _, _, let body, _):
            return body.children

        default:
            return []
        }
    }
}


func unparenExpr(_ e: AstNode) -> AstNode {
    var curr = e
    while case .exprParen(let expr, _) = curr {
        curr = expr
    }

    return curr
}

/// Expands any list or decl into non list nodes into [AstNode]
func explode(_ n: AstNode) -> [AstNode] {

    switch n {
    case .stmtEmpty:
        return []

    case .stmtBlock(let elements, _):
        return elements

    case .exprParen(let expr, _):
        return explode(expr)

    case .list(let vals, _):
        return vals

    case .declValue(let decl) where decl.names.count == decl.values.count:
        return zip(decl.names, decl.values)
            .map { name, value in
                return AstNode.declValue(isRuntime: decl.isRuntime, names: [name], type: decl.type, values: [value], decl.4)
            }

    case .declValue(let decl) where decl.values.isEmpty:
        return decl.names
            .map {
                AstNode.declValue(isRuntime: decl.isRuntime, names: [$0], type: decl.type, values: [], decl.4)
            }

    default:
        return [n]
    }
}

/// Takes a node and appends or creates a list of `self + r`
func append(_ l: AstNode, _ r: AstNode) -> AstNode {

    let newRange = l.startLocation ..< r.endLocation
    switch (l, r) {
    case (.list(let lNodes, _), .list(let rNodes, _)):
        return AstNode.list(lNodes + rNodes, newRange)

    case (_, .list(let nodes, _)):
        return AstNode.list([l] + nodes, newRange)

    case (.list(let nodes, _), _):
        return AstNode.list(nodes + [r], newRange)

    case (_, _):
        return AstNode.list([l, r], newRange)
    }
}


// MARK: Description

extension AstNode: CustomStringConvertible {

    var description: String {

        switch self {
        case .invalid(let location):
            return "<invalid at \(location)>"

        case .list(let nodes, _):
            return nodes.description

        case .comment(let contents, _):
            return "/*\(contents)*/"

        case .ident(let ident, _):
            return ident

        case .directive(let directive, let args, _):
            return "\(directive) \(args.commaSeparated)"

        case .ellipsis(let expr, _):
            return "..\(expr)"

        case .litInteger(let i, _):
            return i.description

        case .litFloat(let d, _):
            return d.description

        case .litString(let s, _):
            return "\"\(s)\""

        case .litProc(let type, let body, _):
            return "\(type) \(body)"

        case .litCompound(let type, let elements, _):
            return type.description + "{ " + elements.map({ $0.description }).joined(separator: ", ") + " }"

        case .litStruct(let members, _):
            return "struct { " + members.map({ $0.description }).joined(separator: "; ") + " }"

        case .litEnum(let cases, _):
            return "enum { " + cases.map({ $0.description }).joined(separator: ", ") + " }"
            
        case .declValue(let isRuntime, let names, let type, let values, _):
            let declChar = isRuntime ? "=" : ":"

            if values.isEmpty {
                return "\(names.commaSeparated) : \(type!)"
            } else if let type = type {
                return "\(names.commaSeparated) : \(type) \(declChar) \(values.commaSeparated)"
            }
            return "\(names.commaSeparated) :\(declChar) \(values.commaSeparated)"

        case .declImport(let path, _, let importName, _):
            if let importName = importName {
                return "#import \(path) \(importName)"
            }
            return "#import \(path)"

        case .declLibrary(let path, _, let libName, _):
            if let libName = libName {
                return "#library \(path) \(libName)"
            }
            return "#library \(path)"


        case .exprCall(let receiver, let args, _):
            return "\(receiver)(\(args.commaSeparated))"

        case .exprSubscript(let receiver, let value, _):
            return "\(receiver)[\(value)]"

        case .exprParen(let expr, _):
            return "(\(expr))"

        case .exprDeref(let expr, _):
            return "<\(expr)"

        case .exprUnary(let op, let expr, _):
            return "\(op)\(expr)"

        case .exprBinary(let op, let lhs, let rhs, _):
            return "\(lhs) \(op) \(rhs)"

        case .exprTernary(let cond, let then, let el, _):
            return "\(cond) ? \(then) : \(el)"

        case .exprSelector(let receiver, let member, _):
            return "\(receiver).\(member)"

        case .stmtExpr(let expr):
            return expr.description

        case .stmtEmpty(_):
            return ";" // NOTE(vdka): Is this right?

        case .stmtAssign(let op, let lhs, let rhs, _):
            return "\(lhs.commaSeparated) \(op) \(rhs.commaSeparated)"

        case .stmtBlock:
            return "{ /* ... */ }" // NOTE(vdka): Is this good?

        case .stmtIf:
            return "if"

        case .stmtReturn(let nodes, _):
            return "return \(nodes.commaSeparated)"

        case .stmtFor:
            return "for"
            
        case .stmtSwitch:
            return "switch"
            
        case .stmtCase(let match, _, _):
            if let match = match {
                return "case \(match.description)"
            }
            return "default"

        case .stmtDefer(let expr, _):
            return "defer \(expr)"

        case .stmtBreak:
            return "break"

        case .stmtContinue:
            return "continue"

        case .typeProc(let params, let results, _):
            return "(\(params.commaSeparated)) -> \(results.commaSeparated)"

        case .typePointer(let type, _):
            return "*\(type)"

        case .typeNullablePointer(let type, _):
            return "^\(type)"

        case .typeArray(let count, let type, _):
            return "[\(count?.description ?? "0")]\(type)"
        }
    }
}

extension Array where Element == AstNode {

    var commaSeparated: String {
        return self.map({ $0.description }).joined(separator: ", ")
    }
}


// MARK: Printing

extension AstNode {

    var shortName: String {

        switch self {
        case .invalid: return "invalid"
        case .list: return "list"
        case .comment: return "comment"
        case .ident: return "ident"
        case .directive: return "directive"
        case .ellipsis: return "ellipsis"
        case .litInteger: return "litInteger"
        case .litFloat: return "litFloat"
        case .litString: return "litString"
        case .litProc: return "litProc"
        case .litCompound: return "litCompound"
        case .litStruct: return "litStruct"
        case .litEnum: return "litEnum"
        case .declValue(let decl): return decl.isRuntime ? "declRt" : "declCt"
        case .declImport: return "declImport"
        case .declLibrary: return "declLibrary"
        case .exprDeref: return "exprDeref"
        case .exprParen: return "exprParen"
        case .exprUnary: return "exprUnary"
        case .exprBinary: return "exprBinary"
        case .exprSelector: return "exprSelector"
        case .exprCall: return "exprCall"
        case .exprSubscript: return "exprSubscript"
        case .exprTernary: return "exprTernary"
        case .stmtEmpty: return "stmtEmpty"
        case .stmtAssign: return "stmtAssign"
        case .stmtBlock: return "stmtBlock"
        case .stmtIf: return "stmtIf"
        case .stmtReturn: return "stmtReturn"
        case .stmtFor: return "stmtFor"
        case .stmtSwitch: return "stmtSwitch"
        case .stmtCase(let match, _, _): return match == nil ? "stmtDefaultCase" : "stmtCase"
        case .stmtDefer: return "stmtDefer"
        case .stmtBreak: return "stmtBreak"
        case .stmtContinue: return "stmtContinue"
        case .typeProc: return "typeProc"
        case .typeArray: return "typeArray"
        case .typePointer: return "typePointer"
        case .typeNullablePointer: return "typeNullablePointer"
        case .stmtExpr: return "stmtExpr"
        }
    }

    /// - Parameter specialName: An name to use in place of the nodes short name.
    func pretty(depth: Int = 0, includeParens: Bool = true, specialName: String? = nil) -> String {

        var unlabeled: [String] = []
        var labeled: [(String, String)] = []

        var children: [AstNode] = []

        // used to emit a node with a different short name ie: list node as parameters or results
        var renamedChildren: [(String, AstNode)] = []

        switch self {
        case .invalid(let location):
            labeled.append(("location", location.description))

        case .list(let nodes, _):

            if nodes.reduce(true, { $0.0 && $0.1.isIdent }) {
                unlabeled.append(nodes.commaSeparated)
            } else {
                children.append(contentsOf: nodes)
            }

        case .comment:
            break

        case .ident(let ident, _):
            unlabeled.append(ident)

        case .directive(let directive, _, _):
            unlabeled.append(directive)

        case .ellipsis(let expr, _):
            children.append(expr)

        case .litInteger(let val, _):
            unlabeled.append("'" + val.description + "'")

        case .litFloat(let val, _):
            unlabeled.append("'" + val.description + "'")

        case .litString(let val, _):
            unlabeled.append("\"" + val + "\"")

        case .litProc(let type, let body, _):
            labeled.append(("type", type.description))
            guard case .typeProc(let params, let results, _) = type else {
                break // NOTE(vdka): Do we want to break?
            }

            let emptyList = AstNode.list([], SourceLocation.unknown ..< .unknown)
            var paramsList = emptyList
            for param in params {
                for decl in explode(param) {
                    paramsList = append(paramsList, decl)
                }
            }

            var resultList = emptyList
            for result in results {
                for decl in explode(result) {
                    resultList = append(resultList, decl)
                }
            }
            renamedChildren.append(("parameters", paramsList))
            renamedChildren.append(("results", resultList))

            children.append(body)

        case .litCompound(let type, let elements, _):
            labeled.append(("type", type.description))
            children.append(contentsOf: elements)

        case .litStruct(let members, _):
            children.append(contentsOf: members)

        case .litEnum(let cases, _):
            children.append(contentsOf: cases)
            
        case .exprParen(let expr, _):
            children.append(expr)

        case .exprDeref(let expr, _):
            children.append(expr)

        case .exprUnary(let op, let expr, _):
            unlabeled.append("'" + op.rawValue + "'")
            children.append(expr)

        case .exprBinary(let op, let lhs, let rhs, _):
            unlabeled.append("'" + op.rawValue + "'")
            children.append(lhs)
            children.append(rhs)

        case .exprSelector(let receiver, let selector, _):
            children.append(receiver)
            children.append(selector)

        case .exprCall(let receiver, let args, _):
            unlabeled.append(receiver.description)
            children.append(contentsOf: args)

        case .exprSubscript(let receiver, let value, _):
            unlabeled.append(receiver.description)
            children.append(value)

        case .exprTernary(let cond, let trueBranch, let falseBranch, _):
            children.append(cond)
            children.append(trueBranch)
            children.append(falseBranch)

        case .stmtEmpty(_):
            break

        case .stmtExpr(let ast):
            children.append(ast)

        case .stmtAssign(let op, let lhs, let rhs, _):
            unlabeled.append(op.rawValue)
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
            if let initializer = initializer {
                let wrapped = AstNode.stmtExpr(initializer)
                renamedChildren.append(("initializer", wrapped))
            }
            if let cond = cond {
                let wrapped = AstNode.stmtExpr(cond)
                renamedChildren.append(("condition", wrapped))
            }
            if let post = post {
                let wrapped = AstNode.stmtExpr(post)
                renamedChildren.append(("post", wrapped))
            }
            children.append(body)
            
        case .stmtSwitch(let subject, let cases, _):
            if let subject = subject {
                renamedChildren.append(("subject", subject))
            }
            
            children.append(contentsOf: cases)
            
        case .stmtCase(let match, let stmts, _):
            if let match = match {
                renamedChildren.append(("match", match))
            }
            
            children.append(stmts)

        case .stmtDefer(let stmt, _):
            children.append(stmt)

        case .stmtBreak, .stmtContinue:
            break

        case .declValue(_, let names, let type, let values, _):
            assert(names.reduce(true, { $0.0 && $0.1.isIdent }))

            labeled.append(("names", names.commaSeparated))

            if let type = type {
                labeled.append(("type", type.description))
            }
            if !values.isEmpty {

                // If all of the values are simple
                if values.reduce(true, { $0.0 && ($0.1.isIdent || $0.1.isBasicLit) }) {
                    labeled.append(("values", values.commaSeparated))
                } else {
                    children += values
                }
            }

        case .declImport(let path, _, importName: let importName, _):
            unlabeled.append(path.description)
            if let importName = importName {
                labeled.append(("as", importName.description))
            } else if case .litString(let pathString, _) = path {
                let (importName, error) = Checker.pathToEntityName(pathString)
                if error {
                    labeled.append(("as", "<invalid>"))
                } else {
                    labeled.append(("as", importName))
                }
            }

        case .declLibrary(let path, _, let libName, _):
            unlabeled.append(path.description)
            if let libName = libName {
                labeled.append(("as", libName.description))
            } else if case .litString(let pathString, _) = path {
                let (importName, error) = Checker.pathToEntityName(pathString)
                if error {
                    labeled.append(("as", "<invalid>"))
                } else {
                    labeled.append(("as", importName))
                }
            }

        case .typeProc(let params, let results, _):
            let emptyList = AstNode.list([], SourceLocation.unknown ..< .unknown)
            var paramsList = emptyList
            for param in params {
                for decl in explode(param) {
                    paramsList = append(paramsList, decl)
                }
            }

            var resultList = emptyList
            for result in results {
                for decl in explode(result) {
                    resultList = append(resultList, decl)
                }
            }
            renamedChildren.append(("parameters", paramsList))
            renamedChildren.append(("results", resultList))

        case .typePointer(let type, _):
            labeled.append(("type", type.description))

        case .typeNullablePointer(let type, _):
            labeled.append(("type", type.description))

        case .typeArray(let count, let type, _):
            labeled.append(("count", count?.description ?? "0"))
            labeled.append(("type", type.description))
        }

        let indent = (0...depth).reduce("\n", { $0.0 + "  " })
        var str = indent

        if includeParens {
            str.append("(")
        }

        if let specialName = specialName {
            str.append(specialName.colored(.blue))
        } else {
            str.append(shortName.colored(.blue))
        }

        str.append(unlabeled.reduce("", { [$0.0, " ", $0.1.colored(.red)].joined() }))
        str.append(labeled.reduce("", { [$0.0, " ", $0.1.0.colored(.white), ": '", $0.1.1.colored(.red), "'"].joined() }))

        renamedChildren.map({ $0.1.pretty(depth: depth + 1, specialName: $0.0) }).forEach({ str.append($0) })
        children.map({ $0.pretty(depth: depth + 1, includeParens: true) }).forEach({ str.append($0) })

        if includeParens {
            str.append(")")
        }

        return str
    }


    /// - Parameter specialName: An name to use in place of the nodes short name.
    func prettyTyped(checker: Checker, depth: Int = 0, includeParens: Bool = true, specialName: String? = nil) -> String {

        var unlabeled: [String] = []
        var labeled: [(String, String)] = []

        var children: [AstNode] = []

        // used to emit a node with a different short name ie: list node as parameters or results
        var renamedChildren: [(String, AstNode)] = []

        switch self {
        case .invalid(let location):
            labeled.append(("location", location.description))

        case .list(let nodes, _):

            if nodes.reduce(true, { $0.0 && ($0.1.isIdent || $0.1.isBasicLit) }) {
                unlabeled.append(nodes.commaSeparated)
            } else {
                children.append(contentsOf: nodes)
            }

        case .comment:
            break

        case .ident(let ident, _):
            unlabeled.append(ident)

        case .directive(let directive, _, _):
            unlabeled.append(directive)

        case .ellipsis(let expr, _):
            children.append(expr)

        case .litInteger(let val, _):
            unlabeled.append("'" + val.description + "'")

        case .litFloat(let val, _):
            unlabeled.append("'" + val.description + "'")

        case .litString(let val, _):
            unlabeled.append("\"" + val + "\"")

        case .litProc(let type, let body, _):
            guard case .typeProc(let params, let results, _) = type else {
                panic()
            }

            let emptyList = AstNode.list([], SourceLocation.unknown ..< .unknown)
            var paramsList = emptyList
            for param in params {
                for decl in explode(param) {
                    paramsList = append(paramsList, decl)
                }
            }

            var resultList = emptyList
            for result in results {
                for decl in explode(result) {
                    resultList = append(resultList, decl)
                }
            }
            renamedChildren.append(("parameters", paramsList))
            renamedChildren.append(("results", resultList))

            children.append(body)

        case .litCompound(let type, let elements, _):
            labeled.append(("type", type.description))
            children.append(contentsOf: elements)

        case .litStruct(let members, _):
            children.append(contentsOf: members)
            
        case .litEnum(let cases, _):
            children.append(contentsOf: cases)

        case .exprDeref(let expr, _):
            children.append(expr)

        case .exprUnary(let op, let expr, _):
            unlabeled.append(op.rawValue)
            children.append(expr)

        case .exprParen(let expr, _):
            children.append(expr)

        case .exprBinary(let op, let lhs, let rhs, _):
            unlabeled.append(op.rawValue)
            children.append(lhs)
            children.append(rhs)

        case .exprSelector(let receiver, let selector, _):
            children.append(receiver)
            children.append(selector)

        case .exprCall(let receiver, let args, _):
            unlabeled.append(receiver.description)
            children.append(contentsOf: args)

        case .exprSubscript(let receiver, let value, _):
            unlabeled.append(receiver.description)
            children.append(value)

        case .exprTernary(let cond, let trueBranch, let falseBranch, _):
            children.append(cond)
            children.append(trueBranch)
            children.append(falseBranch)

        case .stmtEmpty(_):
            break

        case .stmtExpr(let ast):
            children.append(ast)

        case .stmtAssign(let op, let lhs, let rhs, _):
            unlabeled.append(op.rawValue)
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
            if let initializer = initializer {
                let wrapped = AstNode.stmtExpr(initializer)
                renamedChildren.append(("initializer", wrapped))
            }
            if let cond = cond {
                let wrapped = AstNode.stmtExpr(cond)
                renamedChildren.append(("condition", wrapped))
            }
            if let post = post {
                let wrapped = AstNode.stmtExpr(post)
                renamedChildren.append(("post", wrapped))
            }
            children.append(body)
            
        case .stmtSwitch(let subject, let cases, _):
            if let subject = subject {
                renamedChildren.append(("subject", subject))
            }
            
            children.append(contentsOf: cases)
            
        case .stmtCase(let match, let stmts, _):
            if let match = match {
                renamedChildren.append(("match", match))
            }
            
            children.append(stmts)
            
        case .stmtDefer(let stmt, _):
            children.append(stmt)

        case .stmtBreak, .stmtContinue:
            break

        case .declValue(_, let names, _, let values, _):

            if names.reduce(true, { $0.0 && $0.1.isIdent }) {
                labeled.append(("names", names.commaSeparated))
            } else {
                children += names
            }
            if !values.isEmpty {
                if values.reduce(true, { $0.0 && $0.1.isIdent }) {
                    labeled.append(("values", values.commaSeparated))
                } else {
                    children += values
                }
            }

        case .declImport(let path, _, importName: let importName, _):
            unlabeled.append(path.description)
            if let importName = importName {
                labeled.append(("as", importName.description))
            } else if case .litString(let pathString, _) = path {
                let (importName, error) = Checker.pathToEntityName(pathString)
                if error {
                    labeled.append(("as", "<invalid>"))
                } else {
                    labeled.append(("as", importName))
                }
            }

        case .declLibrary(let path, _, let libName, _):
            unlabeled.append(path.description)
            if let libName = libName {
                labeled.append(("as", libName.description))
            } else if case .litString(let pathString, _) = path {
                let (importName, error) = Checker.pathToEntityName(pathString)
                if error {
                    labeled.append(("as", "<invalid>"))
                } else {
                    labeled.append(("as", importName))
                }
            }

        case .typeProc(let params, let results, _):
            let emptyList = AstNode.list([], SourceLocation.unknown ..< .unknown)
            var paramsList = emptyList
            for param in params {
                for decl in explode(param) {
                    paramsList = append(paramsList, decl)
                }
            }

            var resultList = emptyList
            for result in results {
                for decl in explode(result) {
                    resultList = append(resultList, decl)
                }
            }
            renamedChildren.append(("parameters", paramsList))
            renamedChildren.append(("results", resultList))

        case .typePointer(let type, _):
            labeled.append(("type", type.description))

        case .typeNullablePointer(let type, _):
            labeled.append(("type", type.description))

        case .typeArray(let count, let type, _):
            labeled.append(("count", count?.description ?? "0"))
            labeled.append(("type", type.description))
        }

        let indent = (0...depth).reduce("\n", { $0.0 + "  " })
        var str = indent

        if includeParens {
            str.append("(")
        }

        if let specialName = specialName {
            str.append(specialName.colored(.blue))
        } else {
            str.append(shortName.colored(.blue))
        }

        str.append(unlabeled.reduce("", { [$0.0, " ", $0.1.colored(.red)].joined() }))
        str.append(labeled.reduce("", { [$0.0, " ", $0.1.0.colored(.white), ": '", $0.1.1.colored(.red), "'"].joined() }))

        if let type = checker.info.types[self] {
            str.append(" type: ".colored(.cyan))
            str.append("'" + type.description + "'")
        } else if let decl = checker.info.decls[self] {
            str.append(" types: '")

            str.append(decl.entities.map({ $0.type!.description }).joined(separator: ", "))
            str.append("'")
        }

        renamedChildren.map({ $0.1.pretty(depth: depth + 1, specialName: $0.0) }).forEach({ str.append($0) })
        children.map({ $0.pretty(depth: depth + 1, includeParens: true) }).forEach({ str.append($0) })
        
        if includeParens {
            str.append(")")
        }
        
        return str
    }
}

extension ASTFile {

    func pretty() -> String {
        var description = "(" + "file".colored(.blue) + " '" + fullpath.colored(.red) + "'"
        for node in nodes {
            description += node.pretty(depth: 1)
        }
        description += ")"

        return description
    }

    func prettyTyped(_ checker: Checker) -> String {
        var description = "(" + "file".colored(.blue) + " '" + fullpath.colored(.red) + "'"
        for node in nodes {
            description += node.prettyTyped(checker: checker, depth: 1)
        }
        description += ")"

        return description
    }
}
