
import LLVM

extension IRGenerator {
    
    @discardableResult
    func emitDeferStmt(for node: AstNode) -> IRValue {
        guard case .stmt(.defer(statement: let stmt, _)) = node else {
            preconditionFailure()
        }

        let curBlock = builder.insertBlock!
        let lastBlock = builder.currentFunction!.lastBlock!
        
        let curFunction = builder.currentFunction!

        let returnBlock = curFunction.basicBlocks.reversed().first(where: { $0.name == "return" })!


        var deferBlock: BasicBlock
        if let existingDeferBlock = curFunction.basicBlocks.reversed().first(where: { $0.name == "defer" }) {
            deferBlock = existingDeferBlock
        } else {
            deferBlock = curFunction.appendBasicBlock(named: "defer")
        }

        // if there is a prexisting defer, then we need not add another jump.
        var jmp: IRValue
        if !deferBlock.hasTerminatingInstruction {
            jmp = builder.buildBr(deferBlock)
        } else {
            jmp = curBlock.lastInstruction! as IRValue
        }

        builder.positionAtEnd(of: deferBlock)
        if let firstInst = deferBlock.firstInstruction {
            builder.positionBefore(firstInst)
        }

        // At scope exit, reset the builder position
        defer { builder.position(jmp, block: curBlock) }

        let val = emitStmt(for: stmt)
        if !deferBlock.hasTerminatingInstruction {
            builder.buildBr(returnBlock)
        }
        return val
    }
}
