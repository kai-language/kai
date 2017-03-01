
/*
extension AstNode: CustomStringConvertible {

    func pretty(depth: Int = 0) -> String {
        var description = ""

        let indentation = (0...depth).reduce("\n", { $0.0 + "  " })

        description += indentation + "(" + String(describing: self)

        let childDescriptions = self.children
            .map { $0.pretty(depth: depth + 1) }
            .reduce("", { $0 + $1})

        description += childDescriptions

        description += ")"


        return description
    }
}
*/

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

            case .proc(let procSource, type: let type, _):
                return "native " + type.typeDescription

            case .compound(type: let type, elements: _, _):
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
                    guard case .field(names: let names, type: let type, _) = node else {
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
            case .proc(params: let params, results: let results, _):
                return params.fieldListDescription + " -> " + results.fieldListDescription

            case .struct(fields: _, _):
                return "struct"

            case .array(count: _, baseType: let baseType, _):
                return "[]" + baseType.typeDescription

            case .dynArray(baseType: let baseType, _):
                return "[..]" + baseType.typeDescription

            case .enum(baseType: _, fields: _, _):
                return "enum"

            case .pointer(baseType: let baseType, _):
                return "*" + baseType.typeDescription

            case .helper(type: let type, _):
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

        case .argument(label: _, value: let val, _):
            // TODO(vdka): print labels.
            name = "argument"
            unlabeled.append(val.pretty(depth: depth + 1, includeParens: true))

        case .field(names: let names, type: _, _):
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

            case .proc(let procSource, type: let type, _):
                name = "proc"
                labeled["type"] = type.typeDescription

                // TODO(vdka): work out how to nicely _stringify_ a node
                switch procSource {
                case .native(let body):
                    children.append(body)

                case .foreign(lib: _, symbol: _):
                    break
                }

            case .compound(type: _, elements: _, _):
                name = "compoundLit"
//                labeled["type"] = type.desc
            }

        case let .expr(expr):
            switch expr {
            case .bad(let range):
                name = "badExpr"
                unlabeled.append(range.description)

            case .unary(op: let op, expr: let expr, _):
                name = "unaryExpr"
                unlabeled.append(op)
                children.append(expr)

            case .binary(op: let op, lhs: let lhs, rhs: let rhs, _):
                name = "binaryExpr"
                unlabeled.append(op)
                children.append(lhs)
                children.append(rhs)

            case .paren(expr: let expr, _):
                name = "parenExpr"
                children.append(expr)

            case .selector(receiver: let receiver, selector: let selector, _):
                name = "selectorExpr"
                children.append(receiver)
                children.append(selector)

            case .subscript(receiver: let receiver, index: let index, _):
                name = "subscriptExpr"
                children.append(receiver)
                children.append(index)

            case .deref(receiver: let receiver, _):
                name = "dereferenceExpr"
                children.append(receiver)

            case .call(receiver: let receiver, args: let args, _):
                name = "callExpr"
                children.append(receiver)
                children.append(contentsOf: args)

            case .ternary(cond: let cond, let trueBranch, let falseBranch, _):
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

            case .assign(op: let op, lhs: let lhs, rhs: let rhs, _):
                name = "assignmentStmt"
                unlabeled.append(op)
                children.append(contentsOf: lhs)
                children.append(contentsOf: rhs)

            case .block(statements: let stmts, _):
                name = "blockStmt"
                children.append(contentsOf: stmts)

            case .if(cond: let cond, body: let trueBranch, let falseBranch, _):
                name = "ifStmt"
                children.append(cond)
                children.append(trueBranch)
                if let falseBranch = falseBranch {
                    children.append(falseBranch)
                }

            case .return(results: let results, _):
                name = "returnStmt"
                children.append(contentsOf: results)

            case .for(initializer: let initializer, cond: let cond, post: let post, body: let body, _):
                name = "forStmt"
                children.append(initializer)
                children.append(cond)
                children.append(post)
                children.append(body)

            case .case(list: let list, statements: let stmts, _):
                name = "caseStmt"
                children.append(contentsOf: list)
                children.append(contentsOf: stmts)

            case .defer(statement: let stmt, _):
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

            case .value(isVar: _, names: let names, type: _, values: let values, _):
                name = "decl"
//                labeled["type"] = type?.pretty(depth: depth + 1) ?? "<infered>"
                unlabeled.append(names.first!.identifier)
                children.append(contentsOf: values)

            case .import(relativePath: let relPath, fullPath: let fullPath, importName: let importName, _):
                name = "importDecl"
//                labeled["relPath"] = relPath
                labeled["fullPath"] = fullPath
//                labeled["name"] = importName

            case .library(filePath: let filePath, libName: let libName, _):
                name = "libraryDecl"
                labeled["filePath"] = filePath
                labeled["libName"] = libName
            }

        case .type(let type):
            switch type {
            case .helper(type: _, _):
                name = "helperType"
//                labeled["type"] = type.pretty(depth: depth + 1)

            case .proc(params: let params, results: let results, _):
                name = "procType"
                labeled["params"] = params.pretty(depth: depth + 1)
                labeled["results"] = results.pretty(depth: depth + 1)

            case .pointer(baseType: let type, _):
                name = "pointerType"
                labeled["baseType"] = type.pretty(depth: depth + 1)

            case .array(count: let count, baseType: let baseType, _):
                name = "arrayType"
                labeled["size"] = count.pretty()
                labeled["baseType"] = baseType.pretty()
                // FIXME: These should be inline serialized (return directly?)

            case .dynArray(baseType: let baseType, _):
                name = "arrayType"
                labeled["size"] = "dynamic"
                labeled["baseType"] = baseType.pretty()
                // FIXME: These should be inline serialized

            case .struct(fields: let fields, _):
                name = "structType"
                children.append(contentsOf: fields)

            case .enum(baseType: let baseType, fields: let fields, _):
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
