
import LLVM

extension IRGenerator {
    
    @discardableResult
    func emitDeferStmt(for node: AST.Node) throws -> IRValue {
        let deferedExpr = node.children.first!

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

        // TODO: Generic emit expr (doesn't work for scopes at the moment)
        let val = try emitValue(for: deferedExpr)
        if !deferBlock.hasTerminatingInstruction {
            builder.buildBr(returnBlock)
        }
        return val
    }
}
