import CLLVM

class LLVM {
	static let TRUE: Int32 = 0

	static func print(error: UnsafeMutablePointer<Int8>?, cleanupPointer cleanup: Bool = true) {
		guard let error = error else { Swift.print("error: failed to unwrap llvm error."); return }
		Swift.print(String(cString: error))
		if cleanup {
			LLVMDisposeMessage(error)
		}
	}
}

class Module {
	var name: ByteString

	let llvm_module: LLVMModuleRef

	init(name: ByteString) {
		self.name = name
		self.llvm_module = LLVMModuleCreateWithName(String(name))
	}

	deinit {
		LLVMDumpModule(llvm_module)
	}

	enum LLVMError : Error {
		case failedToGenerateBytecode
		case failedToGenerateIR
	}
}

extension Module {
	func verify() -> Bool {
		var error: UnsafeMutablePointer<Int8>? = nil
		if LLVMVerifyModule(llvm_module, LLVMAbortProcessAction, &error) != LLVM.TRUE {
			LLVM.print(error: error)
			return false
		}

		return true
	}
}