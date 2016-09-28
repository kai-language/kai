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
                guard let type = try solve(given: child.children, in: symbol) else {
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
    
    func solve(given nodes: [AST], in scope: Symbol) throws -> KaiType? {
        var makingProgress = true
        while makingProgress {
            makingProgress = false
            for (index, node) in nodes.enumerated() {
                switch node.kind {
                case .integer(_): return KaiType.integer
                case .real(_): return KaiType.float
                case .string(_): return KaiType.string
                case .boolean(_): return KaiType.boolean
                
                case .operator(let `operator`):
                    return try solve(given: node.children, in: scope)

                //this is either a user defined type or an error
                case .identifier(let name) where index != 0:
                    guard let type = try findSymbol(named: name, in: scope)?.types.first else {
                        print("unidentified symbol: \(name) \(node.parent)")
                        return nil
                    }
                    return type
                default:
                    continue
                }
            }
        }
        return nil
    }
    
    func findSymbol(named name: ByteString, in scope: Symbol) throws -> Symbol? {
        /*guard let symbol = scope.lookup(name) else {
            return nil
        }

        guard let type = symbol.types.firt else {
            //FIXME(Brett) needs to do a recursive solve for
            //undefined symbol
            return nil
        }

        //make sure type isn't a user-defined type, otherwise
        //look up the definition of the type and return it
        switch type {
        case .identifier:
            return try findSymbol(named: name, in: scope)
        default:
            return symbol
       }*/
       
       //FIXME(Brett): need to modify `Symbol` and `SymbolTable` to be able to hold
       //an index for their location in `SymbolTable.symbols`
        guard 
            let symbol = SymbolTable.global.lookup(name),
            let type = symbol.types.first
        else { return nil }

        switch type {
        //case .other(let parentSymbol):
          //  return try parentSymbol
        default:
            return symbol
        }
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