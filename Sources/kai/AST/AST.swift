
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
        case ternary(cond: AstNode, AstNode, AstNode)
    }

    /// Statements do not resolve to an value
    enum Statement {
        case bad(SourceRange)
        case empty(SourceLocation)
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
        case value(isVar: Bool, names: [AstNode], type: AstNode?, values: [AstNode])
        case `import`(relativePath: String, fullPath: String, importName: String, SourceLocation)
        case library(filePath: String, libName: String, SourceLocation)
    }

    enum `Type` {
        case helper(type: AstNode, SourceLocation)
        case proc(params: AstNode, results: AstNode, SourceLocation)
        case pointer(type: AstNode, SourceLocation)
        case array(count: AstNode, elements: [AstNode], SourceLocation)
        case dynArray(elements: [AstNode], SourceLocation)
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

/*
extension AstNode: CustomStringConvertible {

    var description: String {
        // TODO(Brett): make system more robust
        var name: String
        var unlabeled: [String] = []
        var labeled: [String: String] = [:]

        switch self {
        case .ident(let tok):
            name = "ident"
            un
        }

//        return "\(blue)\(name)\(substring ?? "")\(reset)"
    }

    var description: String {
        // TODO(Brett): make system more robust
        let blue = "\u{001B}[34m"
        let reset = "\u{001B}[0m"

        let name: String
        var substring: String? = nil

        switch self {
        case .empty:
            name = "empty"

        case .unknown:
            name = "unknown"

        case .emptyFile(let fileName):
            name = "emptyFile"
            substring = buildSubstring(fileName)

        case .file(let fileName):
            name = "file"
            substring = buildSubstring(fileName)

        case .identifier(let bytes):
            name = "identifier"
            substring = buildSubstring(bytes.string)

        case .import(let file, _):
            name = "import"
            //TODO(Brett): full implementation
            substring = buildSubstring(file)

        case .dispose:
            name = "dispose"

        case .memberAccess:
            name = "memberAccess"

        case .multiple:
            name = "multiple"

        case .scope(_):
            name = "scope"

        case .infixOperator(let op):
            name = "infixOperator"
            substring = buildSubstring(op.string)

        case .prefixOperator(let op):
            name = "prefixOperator"
            substring = buildSubstring(op.string)

        case .postfixOperator(let op):
            name = "postfixOperator"
            substring = buildSubstring(op.string)

        // FIXME(vdka): implement
        case .decl(let declaration):
            switch declaration {
            case .bad(_):
                name = "badDecl"

            case .value(let value):
                name = "decl"

                let typeName = value.type?.description ?? "unkown"
                let values = value.values.reduce("") { str, node in
                    return str + "\(node.description)"
                }
                substring = buildSubstring("type=\"\(typeName)\" values=\"\(values)\"")

            case .import(let imp):
                name = "import"
                substring = buildSubstring("source=\(imp.relativePath) alias=\(imp.importName)")
            }

        case .assignment(let byteString):
            name = "assignment"
            substring = buildSubstring(byteString.string)

        case .return:
            name = "return"

        case .defer:
            name = "defer"

        case .multipleDeclaration:
            name = "multipleDeclaration"

        case .loop:
            name = "loop"

        case .break:
            name = "break"

        case .continue:
            name = "continue"

        case .conditional:
            name = "conditional"

        case .subscript:
            name = "subscript"

        case .procedureCall:
            name = "procedureCall"

        case .argument:
            name = "argument"

        case .argumentList:
            name = "argumentList"

        case .argumentLabel(let label):
            name = "argumentLabel"
            substring = buildSubstring(label.string)

        case .operator(let op):
            name = "operator"
            substring = buildSubstring(op.string)

        case .operatorDeclaration:
            name = "operatorDeclaration"

        case .boolean(let bool):
            name = "boolean"
            substring = buildSubstring(bool ? "true" : "false", includeQuotes: false)

        case .real(let real):
            name = "real"
            substring = buildSubstring(real.string, includeQuotes: false)

        case .string(let string):
            name = "string"
            substring = buildSubstring(string.string)

        case .integer(let integer):
            name = "integer"
            substring = buildSubstring(integer.string, includeQuotes: false)

        case .procType(let procInfo):

            var desc = "("

            // TODO(vdka): Should remove labels?
            desc += procInfo.params.map({ $0.description }).joined(separator: ",")
            desc += ")"

            desc += " -> "
            desc += procInfo.returns.map({ $0.description }).joined(separator: ",")

            if procInfo.isVariadic {
                desc += "..."
            }

            return desc

        case .procLiteral(type: let type, body: _):
            return type.description

        default:
            name = "Unknown symbol"
        }

        return "\(blue)\(name)\(substring ?? "")\(reset)"
    }
}

private func buildSubstring(_ value: String, includeQuotes: Bool = true) -> String {
    let red = "\u{001B}[31m"
    let reset = "\u{001B}[0m"

    var value = value
    if includeQuotes {
        value.insert("\"", at: value.startIndex)
        value.append("\"")
    }
    return "\(reset)(\(red)\(value)\(reset))"
}
*/
