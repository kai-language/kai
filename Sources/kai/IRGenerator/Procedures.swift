import LLVM

struct ProcedurePointer {
    
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
}
