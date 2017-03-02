import LLVM

extension IRGenerator {
    func emitGlobalString(name: String? = nil, value: String) -> IRValue {
        return builder.buildGlobalStringPtr(
            value.escaped,
            name: name ?? ""
        )
    }
}

extension String {
    //TODO(vdka): This should be done in the lexer.
    var escaped: String {
        return self.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}
