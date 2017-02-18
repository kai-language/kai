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
            
        default:
            // HACK(Brett): this is so I can continue building function definitions
            // in LLVM
            return VoidType()
            //TODO(Brett): handle all "native" Kai types.
            //throw IRGenerator.Error.unimplemented("Cannot canonicalize type: \(self)")
        }
    }
}
