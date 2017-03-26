import LLVM

extension IRGenerator {
    func emitGlobalString(name: String? = nil, value: String) -> IRValue {
        return builder.buildGlobalStringPtr(
            value.escaped,
            name: name ?? ""
        )
    }
    
    func emitGlobal(name: String? = nil, type: IRType? = nil, value: IRValue? = nil) -> IRValue {
        let name = name ?? ""
        
        if let value = value {
            return builder.addGlobal(name, initializer: value)
        } else if let type = type {
            return builder.addGlobal(name, type: type)
        } else {
            preconditionFailure()
        }
    }
}

extension String {
    //TODO(vdka): This should be done in the lexer.
    var escaped: String {
        return self.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}
