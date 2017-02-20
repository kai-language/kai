import LLVM

extension IRGenerator {
    func emitValue(for node: AST.Node) throws -> IRValue {
        switch node.kind {
        case .integer(let valueString):
            //NOTE(Brett): should this throw?
            let value = Int(valueString.string) ?? 0
            return IntType.int64.constant(value)
            
        case .boolean(let boolean):
            return IntType.int1.constant(boolean ? 1 : 0)
            
        case .string(let string):
            return emitGlobalString(value: string)
            
        case .identifier(let identifier):
            guard let symbol = SymbolTable.current.lookup(identifier) else {
                fallthrough
            }
            
            return builder.buildLoad(symbol.pointer!)
            
        case .procedureCall:
            return try emitProcedureCall(for: node)
            
        default:
            throw Error.unimplemented("unable to emit value for: \(node.kind)")
        }
    }
    
    func emitGlobalString(name: String? = nil, value: ByteString) -> IRValue {
        return builder.buildGlobalStringPtr(
            value.string,
            name: name ?? ""
        )
    }
}
