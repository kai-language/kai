
struct TypeSolver: Pass, ASTValidator {

    static let name: String = "Type solving"
    static var totalTime: Double = 0

    private let rootNode: AST
    
    init(rootNode: AST) {
        self.rootNode = rootNode
    }
    
    static func run(_ root: AST) throws {
        let solver = TypeSolver(rootNode: root)
        try solver.check(node: root)
    }
    
    func check(nodes: [AST]) throws {
        for node in nodes {
            try check(node: node)
        }
    }

    func check(node: AST) throws {
        for child in node.children {
            if !child.children.isEmpty {
                try check(nodes: child.children)
            }

            switch child.kind {
            case .declaration(let symbol):
                if symbol.type != nil {
                    guard child.children.count > 0 else {
                        break
                    }

                    try check(node: child)
                } else {
                    if 
                        let kind = child.parent?.kind,
                        case .multiple = kind
                    {
                        try solveMultipleDeclaration(child, type: &symbol.type)
                    } else {
                        try solveSingleDeclaration(child, type: &symbol.type)
                    }
                }

            default:
                break
            }
        }
    }
}

extension TypeSolver {

    func solveSingleDeclaration(_ node: AST, type: inout TypeRecord?) throws {

        //FIXME(Brett, vdka): check for expressions when they're parsable
        guard node.children.count == 1 else {
            //TODO(Brett): real errors once I finish this algorithm
            print("expected 1 child got \(node.children.count)")
            return
        }

        guard let child = node.children.first else {
            //TODO(Brett): real errors once I finish this algorithm
            print("error unwrapping child")
            return
        }

        type = try extractType(child)
    }
}

extension TypeSolver {

    func solveMultipleDeclaration(_ node: AST, type: inout TypeRecord?) throws {

        guard let root = node.parent?.parent else {
            //TODO(Brett): real errors once I finish this algorithm
            print("error trying to get parents")
            return
        }

        guard case .multipleDeclaration = root.kind else {
            //TODO(Brett): real errors once I finish this algorithm
            print("expected multiple declaration at: \(root.location)")
            return
        }

        guard root.children.count == 2 else {
            //TODO(Brett): real errors once I finish this algorithm
            print("expected 2 children in declaration: \(root.location)")
            return
        }

        let rightSideChild = root.children[1]
        guard case .multiple = rightSideChild.kind else {
            print("expected multiple in AST: \(root.location)")
            return
        }

        for child in rightSideChild.children {
            //TODO(Brett): make sure all of the multiples have the same type
            type = try extractType(child)
        }
    }
}

extension TypeSolver {
    //FIXME(Brett): remove optional and throw instead
    func extractType(_ node: AST) throws -> TypeRecord {

        switch node.kind {
        case .integer:
            return .unconstrInteger

        case .real:
            return .unconstrFloat

        case .boolean:
            return .unconstrBoolean

        case .string:
            return .unconstrString

        case .identifier(let name):

            // FIXME: would this currently would allow you to use a variable as a type?
            guard let symbolType = try typeForSymbol(named: name) else {
                print("failed to find type for symbol: \(name)")
                return .invalid
            }
            return symbolType

        default:
            print("ERROR: Cannot extract type from node of kind: \(node.kind)")
            return .invalid
        }
    }
}

extension TypeSolver {

    //FIXME(Brett): remove optional and throw instead
    func typeForSymbol(named name: ByteString) throws -> TypeRecord? {
        //TODO(Brett): need proper symbol table traversal and lookup but that
        //requires me to keep track of the current table while traversing the
        //AST
        guard let symbol = SymbolTable.global.lookup(name) else {
            print("ERROR: undefined symbol during type lookup: \(name)")
            return nil
        }

        //FIXME: if the symbol is `nil`, attempt to solve it first
        return symbol.type
    }
}

extension TypeSolver {
  struct Error: CompilerError {


    var severity: Severity
    var message: String?
    var location: SourceLocation
    var highlights: [SourceRange]

    enum Reason {
      case unidentifiedSymbol
    }
  }
}
