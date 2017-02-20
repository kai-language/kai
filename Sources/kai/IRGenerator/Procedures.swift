import LLVM

struct ProcedurePointer {
    let symbol: Symbol
    let pointer: Function
    var args: [IRValue]
    let returnType: IRType
    var returnBlock: BasicBlock
    var returnValuePointer: IRValue?
}

extension IRGenerator {
    func emitEntryBlockAlloca(
        in function: Function,
        type: IRType,
        named name: String,
        default defaultValue: IRValue? = nil
    ) -> IRValue {
        let entryBlock = function.entryBlock!
        if let first = entryBlock.firstInstruction {
            builder.position(first, block: entryBlock)
        }
        
        let allocation = builder.buildAlloca(type: type, name: name)
        
        if let currentBlock = builder.insertBlock {
            builder.positionAtEnd(of: currentBlock)
        }
        
        if let defaultValue = defaultValue {
            builder.buildStore(defaultValue, to: allocation)
        }
        
        return allocation
    }
    
    func emitProcedurePrototype(
        _ name: String,
        labels: [(callsite: ByteString?, binding: ByteString)]?,
        types: [KaiType],
        returnType: KaiType,
        isNative: Bool
    ) throws -> Function {
        if let function = module.function(named: name) {
            return function
        }
        
        let args = try types.map { try $0.canonicalized() }
        let canonicalizedReturnType = try returnType.canonicalized()
        
        let functionType = FunctionType(
            argTypes: args,
            returnType: canonicalizedReturnType
        )
        
        let function = builder.addFunction(name, type: functionType)
        
        if let labels = labels, isNative {
            for (var param, name) in zip(function.parameters, labels) {
                param.name = name.binding.string
            }
        }
        
        return function
    }
    
    func emitProcedureDefinition(_ node: AST.Node) throws -> Function {
        guard let (symbol, labels, types, returnType) = node.procedurePrototype else {
            throw Error.preconditionNotMet(expected: "procedure", got: "\(node)")
        }
        
        let function = try emitProcedurePrototype(
            symbol.name.string,
            labels: labels,
            types: types,
            returnType: returnType,
            isNative:  symbol.source == .native
        )
        
        switch symbol.source {
        case .llvm(let funcName):
            emitLLVMForeignDefinition(funcName, func: function)
            return function
            
        case .extern(_):
            return function
            
        case .native:
            guard
                let scopeChild = node.children.first,
                case .scope(let scope) = scopeChild.kind
                else {
                    throw Error.preconditionNotMet(expected: "scope", got: "")
            }
            
            SymbolTable.current = scope
            defer {
                SymbolTable.pop()
            }
            
            let entryBlock = function.appendBasicBlock(named: "entry")
            let returnBlock = function.appendBasicBlock(named: "return")
            let returnTypeCanonicalized = try returnType.canonicalized()
            var resultPtr: IRValue? = nil
            
            builder.positionAtEnd(of: entryBlock)

            if returnType != .void && !(returnTypeCanonicalized is VoidType) {
                //TODO(Brett): store result and figure out how to use it later
                resultPtr = emitEntryBlockAlloca(
                    in: function, type: returnTypeCanonicalized, named: "result"
                )
            }
            
            var argPointers: [IRValue] = []
            let args = try types.map { try $0.canonicalized() }
            for (i, arg) in args.enumerated() {
                //TODO(Brett): insert pointers into current symbol table
                let parameter = function.parameter(at: i)!
                let name = labels?[i].binding.string ?? ""
                let ptr = emitEntryBlockAlloca(
                    in: function,
                    type: arg,
                    named: name,
                    default: parameter
                )
                
                //NOTE(Brett): It may be better to add these to the symbol instead
                //TODO(Brett): Yup! Add these to the symbol table.
                try SymbolTable.current.insert(Symbol(
                    labels![i].binding,
                    location: SourceLocation.unknown,
                    pointer: ptr
                ))

                argPointers.append(ptr)
            }
            
            // NOTE(Brett): May have to work out some sort of stack when nested
            // procedures are supported.
            currentProcedure = ProcedurePointer(
                symbol: symbol,
                pointer: function,
                args: argPointers,
                returnType: returnTypeCanonicalized,
                returnBlock: returnBlock,
                returnValuePointer: resultPtr
            )
            
            defer {
                currentProcedure = nil
            }
            
            try emitScope(for: scopeChild)
            
            let insert = builder.insertBlock!
            if !insert.hasTerminatingInstruction {
                builder.buildBr(returnBlock)
            }
            
            returnBlock.moveAfter(function.lastBlock!)
            builder.positionAtEnd(of: returnBlock)
            if returnType == .void || returnTypeCanonicalized is VoidType {
                builder.buildRetVoid()
            } else {
                let result = builder.buildLoad(resultPtr!, name: "result")
                builder.buildRet(result)
            }
            
            return function
        }
    }
    
    func emitReturn(for node: AST.Node) throws {
        guard
            let currentProcedure = currentProcedure
        else {
            fatalError("No current procedure")
        }
        
        //TODO(Brett) update this to a call to `emitExpression()`
        let value = try emitValue(for: node.children[0])

        if !(currentProcedure.returnType is VoidType) {
            builder.buildStore(value, to: currentProcedure.returnValuePointer!)
        }
        
        builder.buildBr(currentProcedure.returnBlock)
    }
}
