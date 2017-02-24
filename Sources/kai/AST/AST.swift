
class ASTFile {
    var decls: [AST.Node]
    var scopeLevel: Int
    var scope: Scope?       // NOTE: Created in checker

    // FIXME: I need one of these for each `decl`
    var declInfo: DeclInfo? // NOTE: Created in checker

    // TODO(vdka): Fixes per file
    /*
    var fixCount: Int
    */

    init() {
        self.decls = []
        self.scopeLevel = 0
        self.scope = nil
        self.declInfo = nil
    }
}

class AST {
    typealias Node = AST

    weak var parent: Node?
    var children: [Node]

    var location: SourceLocation?
    var sourceRange: Range<SourceLocation>? {
        didSet {
            location = sourceRange?.lowerBound
        }
    }

    var kind: Kind
    /// - Note: If you create a node without a filePosition it defaults to that if it's first child, should if have children
    init(_ kind: Kind, parent: Node? = nil, children: [Node] = [], location: SourceLocation? = nil) {
        self.kind = kind
        self.parent = parent
        self.children = children
        self.location = location ?? children.first?.location

        for child in children {
            child.parent = self
        }
    }
}

enum ProcBody {
    case native(AST.Node)
    case foreign(library: AST.Node, name: String, linkName: String)
}

enum Declaration {
    // TODO(vdka): SourceRange
    case bad(SourceLocation)
    case value(Value)
    case `import`(Import)

    struct Value {
        var isVar: Bool
        var type: AST.Node?
        var values: [AST.Node]
        // TODO(vdka): Flags
    }

    struct Import {
        var isImport: Bool
        var relativePath: String
        // TODO(vdka): Full path
        var importName: String
    }

    struct ForeignLibrary {
        var filePath: String
        var importedName: String
    }
}

extension AST {

    enum Kind {

        case empty
        case unknown
        case invalid

        case decl(Declaration)

        case emptyFile(name: String)
        case file(name: String)
        case identifier(ByteString)

        case `import`(file: String, namespace: String?)

        /// represents the '_' token
        case dispose

        /// represents a . between this Node's two children
        case memberAccess

        /// this signifies a comma seperates set of values. `x, y = y, x` would parse into
        ///         =
        ///      m    m
        ///     x y  y x
        @available(*, deprecated)
        case multiple

        case procType(ProcInfo)

        // TODO(vdka): Add tags
        case procLiteral(type: AST.Node, body: ProcBody)

        @available(*, deprecated)
        case procedure(Symbol)

        @available(*, deprecated)
        case scope(SymbolTable)

        case scope2(Scope)

        case infixOperator(ByteString)
        case prefixOperator(ByteString)
        case postfixOperator(ByteString)

        @available(*, deprecated)
        case declaration(Symbol)
        case assignment(ByteString)
        case `return`
        case `defer`

        @available(*, deprecated)
        case multipleDeclaration

        /// A loop must have atleast 1 child.
        /// The last child is the expr that should be looped.
        /// Should there be 2 or more child expressions then the second
        ///   to last child is to be treated as a condition.
        /// All other child expressions are to be executed prior to looping.
        case loop
        case `break`
        case `continue`
        case conditional
        case `subscript`

        /// The first child is that which is being called
        case procedureCall
        case argument
        case argumentList
        case argumentLabel(ByteString)

        /// number of child nodes determine the 'arity' of the operator
        case `operator`(ByteString)

        /// This is the symbol of a operatorDeclaration that provides no information
        case operatorDeclaration

        case boolean(Bool)
        case real(ByteString)
        case string(ByteString)
        case integer(ByteString)
        case void
    }
}

extension AST {

    /// Should the AST.Node have a name (is an identifier kind) this is that name.
    var entityName: String? {
        switch self.kind {
        case .identifier(let str):
            return str.string

        default:
            return nil
        }
    }
}

extension AST {
    var isStandalone: Bool {
        switch self.kind {
            case .operatorDeclaration, .declaration(_): return true
            default: return false
        }
    }
}

extension AST.Node.Kind: Equatable {
    static func == (lhs: AST.Node.Kind, rhs: AST.Node.Kind) -> Bool {
        switch (lhs, rhs) {
            case
                (.operator(let l), .operator(let r)),
                (.identifier(let l), .identifier(let r)),
                (.infixOperator(let l), .infixOperator(let r)),
                (.prefixOperator(let l), .prefixOperator(let r)),
                (.postfixOperator(let l), .postfixOperator(let r)):

                return l == r

            default:
                return isMemoryEquivalent(lhs, rhs)
        }
    }
}

extension AST.Node: Hashable {

    static func ==(lhs: AST.Node, rhs: AST.Node) -> Bool {
        return lhs === rhs
    }

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

extension AST.Node {
    //NOTE(Brett): consider some nicer cache system? Maybe iterate over the
    // symbols once and filter them.
    var procedurePrototypes: [Node] {
        return children.filter({
            switch $0.kind {
            case .procedure:
                return true
            default:
                return false
            }
        })
    }
}

extension AST.Node.Kind: CustomStringConvertible {
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

//        case .type(let type):
//            name = "type"
//            substring = buildSubstring(type.description)

        case .procedure(let symbol):
            name = "procedure"
            substring = buildSubstring(symbol.description)

        case .scope:
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

        case .declaration(let symbol):
            name = "declaration"
            substring = buildSubstring(symbol.description, includeQuotes: false)

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
