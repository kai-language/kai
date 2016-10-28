class TypeSolver {
    private var rootNode: AST
    
    init(rootNode: inout AST) {
        self.rootNode = rootNode
    }
    
	static func run(on root: inout AST) throws {
        let solver = TypeSolver(rootNode: &root)
        try solver.check(node: &root)
    }
    
    func check(nodes: inout [AST]) throws {
        for var node in nodes {
            try check(node: &node)
        }
    }

    func check(node: inout AST) throws {
        for var child in node.children {
            if !child.children.isEmpty {
                try check(nodes: &child.children)
            }

            switch child.kind {
            case .declaration(let symbol):
                if let _ = symbol.type {
                    guard child.children.count > 0 else {
                        break
                    }

                    try check(node: &child)
                } else {
                    if 
                        let kind = child.parent?.kind,
                        case .multiple = kind
                    {
                        try solveMultipleDeclaration(&child, type: &symbol.type)
                    } else {
                        try solveSingleDeclaration(&child, type: &symbol.type)
                    }
                }

            default:
                break
            }
        }
    }
}

extension TypeSolver {
    func solveSingleDeclaration(_ node: inout AST, type: inout KaiType?) throws {
        //TODO(Brett)
        print("single")
    }
}

extension TypeSolver {
    func solveMultipleDeclaration(_ node: inout AST, type: inout KaiType?) throws {
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
            switch child.kind {
            case .integer:
                type = .integer
            case .real:
                type = .float
            case .boolean:
                type = .boolean
            case .string:
                type = .string
            //TODO(Brett): handle user symbols
            default:
                print("error unsupported kind: \(child.kind)")
                return
            }
        }
    }
}

extension TypeSolver {
    struct Error: CompilerError {
        var reason: Reason
        var message: String?
        var location: SourceLocation
        
        enum Reason {
            case unidentifiedSymbol
        }
    }
}