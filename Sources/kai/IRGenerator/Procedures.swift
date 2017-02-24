import LLVM

struct ProcedurePointer {
    let scope: Scope
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

    func emitProcedurePrototype(for proc: AST.Node) throws -> Function {
        unimplemented()
    }

    /*
    func emitProcedurePrototype(for symbol: Symbol) throws -> Function {

        // FIXME(vdka): What to do when we have no type for our symbol. Is that a compiler bug?
        let type = symbol.type!
        let name = symbol.name.string
        if let function = module.function(named: name) {
            return function
        }

        guard case .proc(let procInfo) = type.kind else { preconditionFailure() }

        let args = try procInfo.params.map { try $0.canonicalized() }

        let rets = try procInfo.returns.map { try $0.canonicalized() }
        guard rets.count == 1 else { unimplemented() }

         // FIXME: @multiplereturns
        let fnType = FunctionType(argTypes: args, returnType: rets.first ?? VoidType(), isVarArg: procInfo.isVariadic)

        let function = builder.addFunction(name, type: fnType)

        if let labels = procInfo.labels, case .native = type.source {
            for (var param, name) in zip(function.parameters, labels) {
                param.name = name.binding.string
            }
        }

        return function
    }
    */

    func emitProcedureDefinition(_ node: AST.Node) throws -> Function {

        unimplemented("procedure definitions")

        /*
        guard case .procedure(let symbol) = node.kind,
              case .proc(let procInfo)? = symbol.type?.kind
            else {
                throw Error.preconditionNotMet(expected: "procedure", got: "\(node)")
        }

        let function = try emitProcedurePrototype(for: symbol)

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

            // FIXME: @multiplereturns
            let returnType = procInfo.returns.first!

            let entryBlock = function.appendBasicBlock(named: "entry")
            let returnBlock = function.appendBasicBlock(named: "return")
            let returnTypeCanonicalized = try returnType.canonicalized()
            var resultPtr: IRValue? = nil

            builder.positionAtEnd(of: entryBlock)

            // TODO: We don't need to rely upon LLVM for this, we should check if the returnType is a basicType.void. Or is another zerowidth value?
            if !(returnTypeCanonicalized is VoidType) {
                resultPtr = emitEntryBlockAlloca(in: function, type: returnTypeCanonicalized, named: "result")
            }

            var argPointers: [IRValue] = []

            let args = try procInfo.params.map { try $0.canonicalized() }
            for (i, arg) in args.enumerated() {
                //TODO(Brett): insert pointers into current symbol table
                let parameter = function.parameter(at: i)!
                let name = procInfo.labels?[i].binding.string ?? ""
                let argPointer = emitEntryBlockAlloca(in: function, type: arg, named: name, default: parameter)

                //NOTE(Brett): It may be better to add these to the symbol instead
                //TODO(Brett): Yup! Add these to the symbol table.

                let newSymbol = Symbol(procInfo.labels![i].binding, location: SourceLocation.unknown, llvm: argPointer)
                
                try SymbolTable.current.insert(newSymbol)

                argPointers.append(argPointer)
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

            // NOTE(vdka): ProcInfo stores reference to the it's scope node. Do we need to do anything to update that?
            try emitScope(for: scopeChild)

            let insert = builder.insertBlock!
            if !insert.hasTerminatingInstruction {
                builder.buildBr(returnBlock)
            }

            returnBlock.moveAfter(function.lastBlock!)
            builder.positionAtEnd(of: returnBlock)

            // TODO: We don't need to rely upon LLVM for this, we should check if the returnType is a basicType.void. Or is another zerowidth value?
            if returnTypeCanonicalized is VoidType {
                builder.buildRetVoid()
            } else {
                let result = builder.buildLoad(resultPtr!, name: "result")
                builder.buildRet(result)
            }

            return function
        }
        */
    }

    func emitReturn(for node: AST.Node) throws {
        guard
            let currentProcedure = context.currentProcedure
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
