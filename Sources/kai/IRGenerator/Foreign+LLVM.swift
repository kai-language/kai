import LLVM

extension IRGenerator {
    func emitLLVMForeignDefinition(_ funcName: String, func: Function) {
        switch funcName {
        case "add":
            break
            
        case "sub":
            break
            
        default:
            unimplemented("LLVM foreign function: \(funcName.string)")
        }
    }
}
