import LLVM

extension Symbol {
    func canonicalized() throws -> IRType {
        //FIXME(Brett): throw an error message
        guard let type = self.type else {
            print("ERROR: type is nil")
            return VoidType()
        }
        
        switch source {
        case .native:
            return try type.canonicalized()

        case .extern(_):
            unimplemented("Delivered.")
            
        case .llvm(let llvmType):
            switch llvmType {
            // MARK: - Void types
            case "void":
                return VoidType()
                
                
            // MARK: - Integer types
            case "i1":
                return IntType.int1
            case "i8":
                return IntType.int8
            case "i16":
                return IntType.int16
            case "i32":
                return IntType.int32
            case "i64":
                return IntType.int64
            case "i128":
                return IntType.int128
                
            // MARK: - Real types
            case "float":
                return FloatType.float
            case "double":
                return FloatType.double
            case "fp128":
                return FloatType.fp128
            case "x86_fp80":
                return FloatType.x86FP80
            case "ppc_fp128":
                return FloatType.ppcFP128
                
            default:
                //FIXME(Brett): throw an error message
                print("ERROR: unknown LLVM type: \(llvmType.string)")
                return VoidType()
            }
        }
    }
}
