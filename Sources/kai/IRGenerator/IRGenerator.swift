import LLVM

struct IRGenerator {
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
            try emitProcedureDefinition($0)
        }
    }
}

extension IRGenerator {
    @discardableResult
    func emitProcedurePrototype(
        _ name: String,
        labels: [(callsite: ByteString?, binding: ByteString)]?,
        types: [KaiType],
        returnType: KaiType
    ) throws -> Function {
        if let function = module.function(named: name) {
            return function
        }
        
        let args = try types.map {
            try $0.canonicalized()
        }
        
        let functionType = FunctionType(
            argTypes: args,
            returnType: try returnType.canonicalized()
        )
        
        let function = builder.addFunction(name, type: functionType)
        
        if let labels = labels {
            for (var param, name) in zip(function.parameters, labels) {
                param.name = name.binding.string
            }
        }
        
        return function
    }
    
    @discardableResult
    func emitProcedureDefinition(_ node: AST.Node) throws -> Function {
        guard
            case .procedure(let symbol) = node.kind,
            let type = symbol.type,
            case .procedure(let labels, let types, let returnType) = type
        else {
            throw Error.preconditionNotMet(expected: "procedure", got: "\(node.kind)")
        }
        
        let function = try emitProcedurePrototype(
            symbol.name.string,
            labels: labels,
            types: types,
            returnType: returnType
        )
        
        switch symbol.source {
        case .llvm(let funcName):
            emitLLVMForeignDefinition(funcName, func: function)
            
        case .native:
            guard
                let scopeChild = node.children.first?.kind,
                case .scope(let scope) = scopeChild
                else {
                    throw Error.preconditionNotMet(expected: "scope", got: "")
            }
            
            SymbolTable.current = scope
            defer {
                SymbolTable.pop()
            }
        }
        
        return function
        
        //unimplemented("emitProcedureDefinition")
    }
}

extension IRGenerator {
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
        } else {
            throw Error.unimplemented("emitProcedureCall for :\(node)")
        }
        
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
