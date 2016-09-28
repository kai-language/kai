class TypeSolver {
    private var rootNode: AST
    
    init(rootNode: inout AST) {
        self.rootNode = rootNode
    }
    
	static func run(on root: inout AST) throws {
        let solver = TypeSolver(rootNode: &root)
        try solver.check(&root)
    }
    
    func check(_ node: inout AST) throws {
        for var child in node.children {
            switch child.kind {
            //TODO(Brett): need to properly handle assignments, function proto-
            //types and functions calls
            case .assignment:
                break
            case .declaration(let symbol) where symbol.types.first == nil:
                guard child.children.count > 0 else { print("what no children!!!"); continue }
                
                //drop the identifier token
                guard let type = try solve(given: child.children) else {
                    print("unable to solve type")
                    return
                }
                
                symbol.types = [type]
            case .scope:
                try check(&child)
            default:
                continue
            }
        }
    }
    
    func solve(given nodes: [AST]) throws -> KaiType? {
        var makingProgress = true
        while makingProgress {
            makingProgress = false
            
            for node in nodes {
                switch node.kind {
                case .integer(let value): return KaiType.integer(value)
                case .string(let value): return KaiType.string(value)
                
                //this is either a user defined type or an error
                case .identifier(let name):
                    //TODO(Brett): look for `identifier` in the symbol table
                    //if the symbol isn't in the table throw an "unidentified
                    //symbol error."
                    
                    //findSymbol()
                    break
                default:
                    continue
                }
            }
            
        }
        
        return nil
    }
    
    func findSymbol() throws {
        //TODO(Brett): build me
    }
}

extension TypeSolver {
    struct Error: CompilerError {
        var reason: Reason
        var message: String?
        var filePosition: FileScanner.Position
        
        enum Reason {
            case unidentifiedSymbol
        }
    }
}







