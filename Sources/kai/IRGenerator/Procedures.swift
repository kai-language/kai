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

        let prevBlock = builder.insertBlock!

        let entryBlock = function.entryBlock!

        if let first = entryBlock.firstInstruction {
            builder.position(first, block: entryBlock)
        }

        let allocation = builder.buildAlloca(type: type, name: name)

        // return to the prev location
        builder.positionAtEnd(of: prevBlock)

        if let defaultValue = defaultValue {
            builder.buildStore(defaultValue, to: allocation)
        }

        return allocation
    }

    func emitProcedurePrototype(for node: AstNode, named name: String) -> Function {
        if let function = module.function(named: name) {
            return function
        }

        let procType = checker.info.types[node]!
        
        let procIrType = procType.canonicalized() as! FunctionType
        
        let procedure = builder.addFunction(name, type: procIrType)

        // FIXME(vdka): This needs to return to have nicely named params.
//        for (var paramIr, paramNode) in zip(procedure.parameters, params) {
//
//            switch paramNode {
//            case .declValue(_, let names, _, _, _):
//                paramIr.name = names[0].identifier
//
//            default:
//                continue
//            }
//        }

        return procedure
    }

    @discardableResult
    func emitProcedureDefinition(_ identifier: AstNode, _ node: AstNode) -> Function {
        guard case let .litProc(type, body, _) = node, case let .typeProc(params, results, _) = type else {
            preconditionFailure()
        }
        
        let entity = checker.info.definitions[identifier]!

        // TODO(Brett): use mangled name when available
        var name = entity.name
        if case .directive("foreign", let args, _) = body, case .litString(let symbolName, _)? = args[safe: 1] {
            name = symbolName
        }

        let proc = emitProcedurePrototype(for: node, named: name)

        llvmPointers[entity] = proc

        if case .directive("foreign", _, _) = body {
            return proc
        }
        
        let scope = entity.childScope!
        let previousScope = context.scope
        context.scope = scope
        defer {
            context.scope = previousScope
        }
        
        let entryBlock = proc.appendBasicBlock(named: "entry")
        let returnBlock = proc.appendBasicBlock(named: "return")
        
        // TODO(Brett): multiple returns
        let result = results[0]
        let returnType: IRType
        
        switch result {
        // TODO(Brett, vdka): is this hacky?
        case .exprUnary("*", expr: let underlyingTypeIden, _):
            // NOTE(Brett): this _may_ break on nested pointers
            let underlyingType = context.scope.lookup(underlyingTypeIden.identifier)!
            returnType = PointerType(pointee: underlyingType.canonicalized())
            
        default:
            returnType = context.scope.lookup(results[0].identifier)!.canonicalized()
        }

        var resultPtr: IRValue? = nil
        
        builder.positionAtEnd(of: entryBlock)
        
        if !(returnType is VoidType) {
            resultPtr = emitEntryBlockAlloca(in: proc, type: returnType, named: "result")
        }
        
        var args: [IRValue] = []
        for (i, param) in params.enumerated() {
            guard case let .declValue(_, names, _, _, _) = param else {
                preconditionFailure()
            }
            
            let entity = checker.info.definitions[names[0]]!
            
            // TODO(Brett): values
            
            let arg = proc.parameter(at: i)!
            let argPointer = emitEntryBlockAlloca(
                in: proc,
                type: arg.type,
                named: entity.name,
                default: arg
            )
            
            llvmPointers[entity] = argPointer
            args.append(argPointer)
        }
        
        let procPointer = ProcedurePointer(
            scope: scope,
            pointer: proc,
            args: args,
            returnType: returnType,
            returnBlock: returnBlock,
            returnValuePointer: resultPtr
        )
        
        let previousProcPointer = context.currentProcedure
        context.currentProcedure = procPointer
        defer {
            context.currentProcedure = previousProcPointer
        }
        
        emitStmt(for: body)
        
        let insert = builder.insertBlock!
        if !insert.hasTerminatingInstruction {
            builder.buildBr(returnBlock)
        }
        
        returnBlock.moveAfter(proc.lastBlock!)
        builder.positionAtEnd(of: returnBlock)
        
        if returnType is VoidType {
            builder.buildRetVoid()
        } else {
            let result = builder.buildLoad(resultPtr!, name: "result")
            builder.buildRet(result)
        }
        
        return proc
    }

    func emitReturnStmt(for node: AstNode) -> IRValue {
        guard let currentProcedure = context.currentProcedure else {
            // TODO(vdka): This will be fine for instances such as scopes.
            fatalError("Return statement outside of procedure")
        }

        guard case .stmtReturn(let values, _) = node else {
            preconditionFailure()
        }

        unimplemented("Multiple returns", if: values.count > 1)

        if values.count > 0 {
            let value = emitStmt(for: values[0])
            
            if !(value is VoidType) {
                builder.buildStore(value, to: currentProcedure.returnValuePointer!)
            }
        }
        
        
        builder.buildBr(currentProcedure.returnBlock)
        return VoidType().null()
    }
}
