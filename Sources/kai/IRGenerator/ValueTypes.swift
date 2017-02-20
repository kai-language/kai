import LLVM

extension IRGenerator {
    func emitGlobalString(name: String? = nil, value: ByteString) -> IRValue {
        return builder.buildGlobalStringPtr(
            value.string.escaped,
            name: name ?? ""
        )
    }
}

extension String {
    //TODO: More robust system
    var escaped: String {
        return self.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}
