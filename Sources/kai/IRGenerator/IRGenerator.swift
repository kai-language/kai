import LLVM

// TODO(vdka): IRGenerator _should_ possibly take in a file
//  This would mean that the initial context would be file scope. Not universal scope.
class IRGenerator {

    var file: ASTFile
    var context = Context()

    let module: Module
    let builder: IRBuilder
    let internalFuncs: InternalFuncs

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
        case invalidSyntax
        case invalidOperator(String)
        case unidentifiedSymbol(String)
        case preconditionNotMet(expected: String, got: String)
    }
    
    init(_ file: ASTFile) throws {
        self.file = file
        module = Module(name: file.name)
        builder = IRBuilder(module: module)
        internalFuncs = InternalFuncs(builder: builder)
    }
    
    static func build(for file: ASTFile) throws -> Module {
        let generator = try IRGenerator(file)
        try generator.emitGlobals()
        try generator.emitMain()
        
        return generator.module
    }
}

extension IRGenerator {
    func emitMain() throws {
        // TODO(Brett): Update to emit function definition
        let mainType = FunctionType(argTypes: [], returnType: VoidType())
        let main = builder.addFunction("main", type: mainType)
        let entry = main.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entry)

        for child in file.expressions {
            switch child.kind {
            case .procedureCall:
                _  = try emitProcedureCall(for: child)
                
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
    func emitExpression(for node: AST.Node) throws -> IRValue {
        switch node.kind {
        //NOTE(Brett): how do we want to handle different values here, should we
        // continue to ignore them and just return nil?
        case .scope(_):
            for child in node.children {
                _ = try emitExpression(for: child)
            }
            return VoidType().null()
            
        case .assignment:
            return try emitAssignment(for: node)
            
        //case .declaration:
            //return try emitDeclaration(for: node)
            
        case .procedureCall:
            return try emitProcedureCall(for: node)
            
        case .conditional:
            return try emitConditional(for: node)
            
        case .defer:
            return try emitDeferStmt(for: node)
            
        case .operator(_):
            return try emitOperator(for: node)
            
        case .return:
            try emitReturn(for: node)
            return VoidType().null()
            
        case .integer(let valueString):
            //NOTE(Brett): should this throw?
            let value = Int(valueString.string) ?? 0
            return IntType.int64.constant(value)
            
        case .boolean(let boolean):
            return IntType.int1.constant(boolean ? 1 : 0)
            
        case .string(let string):
            return emitGlobalString(value: string)
            
        /*case .identifier(let identifier):
            guard let symbol = SymbolTable.current.lookup(identifier) else {
                fallthrough
            }
            
            return builder.buildLoad(symbol.pointer!)
          */
            
        default:
            unimplemented("unsupported kind: \(node.kind)")
        }
    }
    
    func emitConditional(for node: AST.Node) throws -> IRValue {
        unimplemented()
        
        /*guard let function = currentProcedure?.pointer else {
            preconditionFailure("Not currently in a function")
        }
        
        guard case .conditional = node.kind, node.children.count >= 2 else {
            preconditionFailure("Expected conditional got: \(node.kind)")
        }
        
        let currentBlock = builder.insertBlock!
        let thenBody = function.appendBasicBlock(named: "then")
        let elseBody = function.appendBasicBlock(named: "else")
        let mergeBody = function.appendBasicBlock(named: "merge")
        
        builder.positionAtEnd(of: currentBlock)
        let conditional = try emitExpression(for: node.children[0])
        builder.buildCondBr(condition: conditional, then: thenBody, else: elseBody)
        
        builder.positionAtEnd(of: thenBody)
        guard case .scope(let thenScope) = node.children[1].kind else {
            preconditionFailure("Expected scope for `then` body.")
        }
        context?.scope = thenScope
        defer {
           // SymbolTable.pop()
        }
        
        _ = try emitExpression(for: node.children[1])
        
        if !thenBody.hasTerminatingInstruction {
            builder.buildBr(mergeBody)
        }
        
        if !builder.insertBlock!.hasTerminatingInstruction {
            builder.buildBr(mergeBody)
        }
        
        builder.positionAtEnd(of: elseBody)
        // has else body
        if node.children.count >= 3 {
            if case .scope(let elseScope) = node.children[2].kind {
                SymbolTable.current = thenScope
                defer {
                    //SymbolTable.pop()
                }
            }
            
            _ = try emitExpression(for: node.children[2])
            
            if !elseBody.hasTerminatingInstruction {
                builder.buildBr(mergeBody)
            }
            
            if !builder.insertBlock!.hasTerminatingInstruction {
                builder.buildBr(mergeBody)
            }
            
        } else {
            builder.buildBr(mergeBody)
        }
        
        builder.positionAtEnd(of: mergeBody)
        
        // NOTE(Brett): do we really want to return this?
        return conditional
         */
    }

    @discardableResult
    func emitDeclaration(for node: AST.Node) throws -> IRValue? {
        unimplemented()
        /*
>>>>>>> round2
        guard
            case .declaration(let symbol) = node.kind,
            let type = symbol.type
        else {
            throw Error.preconditionNotMet(expected: "declaration", got: "\(node)")
        }
        
        // what should we do here about forward declarations of foreign variables?
        var defaultValue: IRValue? = nil
        
        if let valueChild = node.children.first {
            defaultValue = try emitExpression(for: valueChild)
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
        let rvalue = try emitExpression(for: node.children[1])

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
            try emitExpression(for: $0)
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
        
        let string = try emitExpression(for: argument)
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
