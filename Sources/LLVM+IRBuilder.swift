import CLLVM

func makeLLVMSumTest() {
	let module = LLVMModuleCreateWithName("Hello, world")
	
	var parameterTypes = [LLVMInt32Type(), LLVMInt32Type()]
	let returnType = LLVMFunctionType(LLVMInt32Type(), &parameterTypes, 2, 0)
	let sum = LLVMAddFunction(module, "sum", returnType)
	
	let entry = LLVMAppendBasicBlock(sum, "entry")
	let builder = LLVMCreateBuilder()
	LLVMPositionBuilderAtEnd(builder, entry)

	let tmp = LLVMBuildAdd(builder, LLVMGetParam(sum, 0), LLVMGetParam(sum, 1), "tmp")
	LLVMBuildRet(builder, tmp)

	var error: UnsafeMutablePointer<Int8>? = nil
	var result = LLVMPrintModuleToFile(module, "sum.ll", &error)
	if result != LLVM.TRUE {
		LLVM.print(error: error)
	}
	print("llvm ir generation: \(result == LLVM.TRUE ? "success" : "failure")")
	result = LLVMWriteBitcodeToFile(module, "sum.bc")
	print("llvm bytecode generation: \(result == LLVM.TRUE ? "success" : "failure")")
}

extension Module {
	func generateBytecode() throws {
		let result = LLVMWriteBitcodeToFile(llvm_module, String(name))
		if result != 0 {
			//TODO(Brett): pull the error message out of LLVM and attach to enum
			throw LLVMError.failedToGenerateBytecode
		}
	}
}