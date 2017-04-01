
import LLVM

extension IRGenerator {
    
    @discardableResult
    func emitDeferStmt(for node: AstNode) -> IRValue {

        guard case .stmtDefer(let stmt, _) = node else {
            fatalError()
        }

        let curBlock = builder.insertBlock!
        let lastBlock = builder.currentFunction!.lastBlock!
        
        let curFunction = builder.currentFunction!

        if context.currentProcedure!.deferBlock == nil {
            context.currentProcedure!.deferBlock = curFunction.appendBasicBlock(named: "defer")
        }

        let returnBlock = context.currentProcedure!.returnBlock
        let deferBlock  = context.currentProcedure!.deferBlock!

        // FIXME(vdka): This is not quite what we want. We want defer to always execute right before
        // we return from the current proc. This will instead execute the moment you leave say, an if
        // or for BasicBlock.
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
