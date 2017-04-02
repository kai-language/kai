import LLVM

struct ProcedurePointer {
    let scope: Scope
    let pointer: Function
    var args: [IRValue]
    let returnType: IRType
    var deferBlock: BasicBlock?
    var returnBlock: BasicBlock
    var returnValuePointer: IRValue?

    init(scope: Scope, pointer: Function, args: [IRValue], returnType: IRType, returnBlock: BasicBlock, returnValuePointer: IRValue?) {
        self.scope = scope
        self.pointer = pointer
        self.args = args
        self.returnType = returnType
        self.deferBlock = nil
        self.returnBlock = returnBlock
        self.returnValuePointer = returnValuePointer
    }
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
        guard case let .litProc(_, body, _) = node else {
            preconditionFailure()
        }

        let prevBlock = builder.insertBlock
        defer {
            if let prevBlock = prevBlock {
                builder.positionAtEnd(of: prevBlock)
            }
        }
        
        let entity = checker.info.definitions[identifier]!

        // TODO(Brett): use mangled name when available
        var name = entity.mangledName!
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

        let type = checker.info.types[node]!

        guard case .proc(let params, let results, _) = type.kind else {
            panic()
        }

        let resultType: IRType

        if results.count == 1, let firstResult = results.first {
            resultType = firstResult.canonicalized()
        } else {
            let resultIrTypes = results.map({ $0.canonicalized() })

            resultType = StructType(elementTypes: resultIrTypes)
        }

        var resultPtr: IRValue? = nil
        
        builder.positionAtEnd(of: entryBlock)
        
        if !(resultType is VoidType) {
            resultPtr = emitEntryBlockAlloca(in: proc, type: resultType, named: "result")
        }
        
        var args: [IRValue] = []
        for (i, param) in params.enumerated() {

            // TODO(Brett): values
            
            let arg = proc.parameter(at: i)!
            let argPointer = emitEntryBlockAlloca(
                in: proc,
                type: arg.type,
                named: entity.mangledName!,
                default: arg
            )
            
            llvmPointers[param] = argPointer
            args.append(argPointer)
        }
        
        let procPointer = ProcedurePointer(
            scope: scope,
            pointer: proc,
            args: args,
            returnType: resultType,
            returnBlock: returnBlock,
            returnValuePointer: resultPtr
        )
        
        let previousProcPointer = context.currentProcedure
        context.currentProcedure = procPointer
        defer {
            context.currentProcedure = previousProcPointer
        }

        guard case .stmtBlock(let stmts, _) = body else {
            panic()
        }
        for stmt in stmts {
            emitStmt(for: stmt)
        }
        
        let insert = builder.insertBlock!
        if !insert.hasTerminatingInstruction {
            builder.buildBr(returnBlock)
        }
        
        returnBlock.moveAfter(proc.lastBlock!)
        builder.positionAtEnd(of: returnBlock)
        
        if resultType is VoidType {
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
