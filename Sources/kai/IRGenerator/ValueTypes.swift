import LLVM

extension IRGenerator {
    func emitInteger() -> IRValue {
        unimplemented("emitInteger")
    }
    
    func emitGlobalString(name: String? = nil, value: ByteString) -> IRValue {
        return builder.buildGlobalStringPtr(
            value.string,
            name: name ?? ""
        )
    }
}
