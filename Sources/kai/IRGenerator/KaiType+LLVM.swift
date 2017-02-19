import LLVM

extension KaiType {
    func canonicalized() throws -> IRType {
        switch self {
        case .boolean:
            return IntType.int1
            
        case .float:
            return FloatType.double
            
        case .integer:
            return IntType.int64
            
        case .void:
            return VoidType()
            
        case .unknown(let identifier):
            guard let symbol = SymbolTable.current.lookup(identifier) else {
                fallthrough
            }
            
            return try symbol.canonicalized()
            
        default:
            //TODO(Brett): handle all "native" Kai types.
            throw IRGenerator.Error.unimplemented("Cannot canonicalize type: \(self)")
        }
    }
}
