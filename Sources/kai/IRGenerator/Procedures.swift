import LLVM

class Procedure {
    let scope: Scope
    let llvm: Function
    var type: FunctionType
    var returnValue: IRValue?
    var deferBlock: BasicBlock?
    var returnBlock: BasicBlock

    init(scope: Scope, llvm: Function, type: FunctionType, returnBlock: BasicBlock, returnValue: IRValue?) {
        self.scope = scope
        self.llvm = llvm
        self.type = type
        self.returnBlock = returnBlock
        self.returnValue = returnValue
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

    func emitProcedurePrototype(for entity: Entity) -> Function {
        if let function = module.function(named: entity.mangledName!) {
            return function
        }
        
        let procIrType = entity.type!.canonicalized() as! FunctionType
        
        let procedure = builder.addFunction(entity.mangledName!, type: procIrType)

        guard case .proc(let params, _, _) = entity.type!.kind else {
            panic()
        }

        for (var paramIr, param) in zip(procedure.parameters, params) {

            if param.name != "_" {
                paramIr.name = param.name
            }
        }

        return procedure
    }

    @discardableResult
    func emitProcedureDefinition(_ entity: Entity, _ node: AstNode) -> Function {

        if let llvmPointer = llvmPointers[entity] {
            return llvmPointer as! Function
        }

        guard case let .litProc(_, body, _) = node else {
            preconditionFailure()
        }

        let prevBlock = builder.insertBlock
        defer {
            if let prevBlock = prevBlock {
                builder.positionAtEnd(of: prevBlock)
            }
        }

        // TODO(Brett): use mangled name when available
        var name = entity.mangledName!
        if case .directive("foreign", let args, _) = body, case .litString(let symbolName, _)? = args[safe: 1] {
            name = symbolName
        }

        let proc = emitProcedurePrototype(for: entity)

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
        let irType = type.canonicalized() as! FunctionType

        guard case .proc(let params, let results, _) = type.kind else {
            panic()
        }

        var resultValue: IRValue? = nil
        
        builder.positionAtEnd(of: entryBlock)
        
        if !(irType.returnType is VoidType) {

            resultValue = emitEntryBlockAlloca(in: proc, type: irType.returnType, named: "result")
        }
        
        var args: [IRValue] = []
        for (i, param) in params.enumerated() {

            // TODO(Brett): values
            
            let arg = proc.parameter(at: i)!
            let argPointer = emitEntryBlockAlloca(in: proc, type: arg.type, named: entity.name)

            builder.buildStore(arg, to: argPointer)
            
            llvmPointers[param] = argPointer
            args.append(argPointer)
        }

        let procedure = Procedure(scope: scope, llvm: proc, type: irType, returnBlock: returnBlock, returnValue: resultValue)
        
        let previousProcPointer = context.currentProcedure
        context.currentProcedure = procedure
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
        
        if irType.returnType is VoidType {
            builder.buildRetVoid()
        } else {
            let result = builder.buildLoad(resultValue!, name: "result")
            builder.buildRet(result)
        }
        
        return proc
    }

    func emitReturnStmt(for node: AstNode) -> IRValue {
        guard let currentProcedure = context.currentProcedure else {
            fatalError("Return statement outside of procedure")
        }

        guard case .stmtReturn(let values, _) = node else {
            panic()
        }

        if values.count == 1, let value = values.first {
            let irValue = emitStmt(for: value)

            if !(irValue is VoidType) {
                builder.buildStore(irValue, to: currentProcedure.returnValue!)
            }
        }
        if values.count > 1 {
            var retVal = builder.buildLoad(currentProcedure.returnValue!)
            for (index, value) in values.enumerated() {
                let irValue = emitStmt(for: value)
                retVal = builder
                    .buildInsertValue(aggregate: retVal, element: irValue, index: index)
            }

            builder.buildStore(retVal, to: currentProcedure.returnValue!)
        }

        builder.buildBr(currentProcedure.returnBlock)
        return VoidType().null()
    }
}
