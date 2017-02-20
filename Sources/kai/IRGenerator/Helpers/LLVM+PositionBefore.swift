
import cllvm
import LLVM

extension IRBuilder {

    func positionAfter(_ inst: Instruction, inBlock block: BasicBlock) {

        if let next = inst.next() {
            positionBefore(next)
            position(next, block: block)
        } else {
            positionAtEnd(of: block)
        }
    }
}
