import LLVM

class IRGenerator {
    var currentProcedure: ProcedurePointer?
    
    //FIXME(Brett):
    //TODO(Brett): will be removed when #foreign is supported
    struct InternalFuncs {
        var puts: Function?
        var printf: Function?
        
        init(builder: IRBuilder) {
            puts = generatePuts(builder: builder)
            printf = nil
        }
        
        func generatePuts(builder: IRBuilder) -> Function {
            let putsType = FunctionType(
                argTypes:[ PointerType(pointee: IntType.int8) ],
                returnType: IntType.int32
            )
            
            return builder.addFunction("puts", type: putsType)
        }
        
        func generatePrintf() -> Function? {
            return nil
        }
    }
    
    enum Error: Swift.Error {
        case unimplemented(String)
        case expectedFileNode
        case unidentifiedSymbol(String)
        case preconditionNotMet(expected: String, got: String)
    }
    
    let module: Module
    let builder: IRBuilder
    let rootNode: AST
    let internalFuncs: InternalFuncs
    
    init(node: AST.Node) throws {
        guard case .file(let fileName) = node.kind else {
            throw Error.expectedFileNode
        }
        
        rootNode = node
        module = Module(name: fileName)
        builder = IRBuilder(module: module)
        internalFuncs = InternalFuncs(builder: builder)
        currentProcedure = nil
    }
    
    static func build(for node: AST.Node) throws {
        let generator = try IRGenerator(node: node)
        try generator.emitGlobals()
        try generator.emitMain()
        
        generator.module.dump()
        try TargetMachine().emitToFile(module: generator.module, type: .object, path: "main.o")
    }
}

extension IRGenerator {
    func emitMain() throws {
        // TODO(Brett): Update to emit function definition
        let mainType = FunctionType(argTypes: [], returnType: VoidType())
        let main = builder.addFunction("main", type: mainType)
        let entry = main.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entry)
        
        for child in rootNode.children {
            switch child.kind {
            case .procedureCall:
                try emitProcedureCall(for: child)
                
            default: break
            }
        }
        
        builder.buildRetVoid()
    }
    
    func emitGlobals() throws {
        try rootNode.procedurePrototypes.forEach {
            _ = try emitProcedureDefinition($0)
        }
    }
}

extension IRGenerator {
    func emit(scope: AST.Node) throws {
        for child in scope.children {
            switch child.kind {
            case .declaration(let symbol):
                _ = try emitDeclaration(for: symbol)
                
            case .procedureCall:
                try emitProcedureCall(for: child)
                
            case .return:
                try emitReturn(for: child)
                
            default:
                print("unsupported kind: \(child.kind)")
                break
            }
        }
    }
    
    func emitDeclaration(for symbol: Symbol) throws -> IRValue {
        guard let type = symbol.type else {
            throw Error.unidentifiedSymbol(symbol.name.string)
        }
        
        switch type {
        case .string:
            break
        case .integer:
            break
        case .float:
            break
        case .boolean:
            break
            
        default:
            unimplemented("emitDeclaration for type: \(type.description)")
        }
        
        unimplemented("emitDeclaration body")
    }
    
    func emitProcedureCall(for node: AST.Node) throws {
        assert(node.kind == .procedureCall)
        
        guard
            node.children.count >= 2,
            let firstNode = node.children.first,
            case .identifier(let identifier) = firstNode.kind
            else {
                throw Error.preconditionNotMet(
                    expected: "identifier",
                    got: "\(node.children.first?.kind)"
                )
        }
        
        let arguments = node.children[1]
        
        // FIXME(Brett):
        // TODO(Brett): will be removed when #foreign is supported
        if identifier == "print" {
            try emitPrintCall(for: arguments)
            return
        }
        
        guard let function = module.function(named: identifier.string) else {
            unimplemented("lazy-generation of procedure prototypes")
        }

        //TODO(Brett): arguments not yet supported
        builder.buildCall(function, args: [])
    }
    
    // FIXME(Brett):
    // TODO(Brett): will be removed when #foreign is supported
    func emitPrintCall(for arguments: AST.Node) throws {
        guard arguments.children.count == 1 else {
            throw Error.preconditionNotMet(expected: "1 argument", got: "\(arguments.children.count)")
        }
        
        let argument = arguments.children[0]
        
        switch argument.kind {
        case .string(let string):
            let stringPtr = emitGlobalString(value: string)
            builder.buildCall(internalFuncs.puts!, args: [stringPtr])
            
        default:
            throw Error.unimplemented("emitPrintCall: \(argument.kind)")
        }
    }
}

extension BasicBlock {
    var hasTerminatingInstruction: Bool {
        guard let instruction = lastInstruction else {
            return false
        }
        
        return instruction.isATerminatorInst
    }
}
