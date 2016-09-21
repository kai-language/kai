class Module {
	var name: ByteString
	//blocks datatype

	init(name: ByteString) {
		self.name = name
	}

	//creates a basic block of code
	func basicBlock(_ builderFunc: (IRBuilder) -> Void) {
		var builder = IRBuilder()
		builderFunc(builder)
	}
}