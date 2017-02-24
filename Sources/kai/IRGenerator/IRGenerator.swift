import LLVM

// TODO(vdka): IRGenerator _should_ possibly take in a file
//  This would mean that the initial context would be file scope. Not universal scope.
class IRGenerator {
    
    var context = Context()

    class Context {

        var currentProcedure: ProcedurePointer?

        var parent: Context? = nil

        var state: State = .global

        var scope: Scope = .universal

        enum State {
            case global

            case procedureBody
            case structureBody
            case enumerationBody

            // allow keywords break & continue
            case loopBody
            
            case procedureCall
        }
    }
    
    //FIXME(Brett):
    //TODO(Brett): will be removed when #foreign is supported
    struct InternalFuncs {
        var puts: Function?
        var printf: Function?
        
        init(builder: IRBuilder) {
            puts = generatePuts(builder: builder)
            printf = generatePrintf(builder: builder)
        }
        
        func generatePuts(builder: IRBuilder) -> Function {
            let putsType = FunctionType(
                argTypes:[ PointerType(pointee: IntType.int8) ],
                returnType: IntType.int32
            )
            
            return builder.addFunction("puts", type: putsType)
        }
        
        func generatePrintf(builder: IRBuilder) -> Function {
            let printfType = FunctionType(
                argTypes: [PointerType(pointee:IntType.int8)],
                returnType: IntType.int32,
                isVarArg: true
            )
            return builder.addFunction("printf", type: printfType)
        }
    }
    
    enum Error: Swift.Error {
        case unimplemented(String)
        case expectedFileNode
        case invalidSyntax
        case invalidOperator(String)
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
        unimplemented()
//        try rootNode.procedurePrototypes.forEach {
//            _ = try emitProcedureDefinition($0)
//        }
    }
}

extension IRGenerator {
    func emitScope(for node: AST.Node) throws {
        for child in node.children {
            switch child.kind {
            case .assignment:
                try emitAssignment(for: child)

            // FIXME(vdka): Implement
            case .decl(_):
                unimplemented()

//            case .declaration:
//                try emitDeclaration(for: child)

            case .procedureCall:
                try emitProcedureCall(for: child)
                
            case .defer:
                try emitDeferStmt(for: child)
                
            case .return:
                try emitReturn(for: child)
                
            default:
                print("unsupported kind: \(child.kind)")
                break
            }
        }
    }

    @discardableResult
    func emitDeclaration(for node: AST.Node) throws -> IRValue? {
        unimplemented()
        /*
        guard
            case .declaration(let symbol) = node.kind,
            let type = symbol.type
        else {
            throw Error.preconditionNotMet(expected: "declaration", got: "\(node)")
        }
        
        // what should we do here about forward declarations of foreign variables?
        guard symbol.source == .native else {
            return nil
        }
        
        var defaultValue: IRValue? = nil
        
        if let valueChild = node.children.first {
            defaultValue = try emitValue(for: valueChild)
        }
        
        let typeCanonicalized = try type.canonicalized()

        let llvm = emitEntryBlockAlloca(
            in: currentProcedure!.pointer,
            type: typeCanonicalized,
            named: symbol.name.string,
            default: defaultValue
        )
        
        symbol.llvm = llvm
        
        return llvm
        */
    }

    @discardableResult
    func emitAssignment(for node: AST.Node) throws -> IRValue {
        //FIXME(Brett): will break if it's multiple assignment
        guard
            case .assignment(_) = node.kind,
            node.children.count == 2
        else {
            throw Error.preconditionNotMet(expected: "assignment", got: "\(node.kind)")
        }
        
        let lvalue = node.children[0]
        guard case .identifier(let identifier) = lvalue.kind else {
            throw Error.preconditionNotMet(expected: "identifier", got: "\(lvalue.kind)")
        }

        let lvalueEntity = context.scope.lookup(identifier.string)!
        let rvalue = try emitValue(for: node.children[1])

        return builder.buildStore(rvalue, to: lvalueEntity.llvm!)
    }

    @discardableResult
    func emitProcedureCall(for node: AST.Node) throws -> IRValue {
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
        
        let argumentList = node.children[1]
        
        // FIXME(Brett):
        // TODO(Brett): will be removed when #foreign is supported
        if identifier == "print" {
            return try emitPrintCall(for: argumentList)
        }
        
        // FIXME(Brett): why is this lookup failing?
        /*guard let symbol = SymbolTable.current.lookup(identifier) else {
            return
        }
        guard let function = symbol.pointer else {
            unimplemented("lazy-generation of procedures")
        }*/
        
        let function = module.function(named: identifier.string)!

        let args = try argumentList.children.map {
            try emitValue(for: $0)
        }
        
        return builder.buildCall(function, args: args)
    }
    
    // FIXME(Brett):
    // TODO(Brett): will be removed when #foreign is supported
    func emitPrintCall(for argumentList: AST.Node) throws -> IRValue {
        guard argumentList.children.count == 1 else {
            throw Error.preconditionNotMet(expected: "1 argument", got: "\(argumentList.children.count)")
        }
        
        let argument = argumentList.children[0]
        
        let string = try emitValue(for: argument)
        return builder.buildCall(internalFuncs.puts!, args: [string])
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
