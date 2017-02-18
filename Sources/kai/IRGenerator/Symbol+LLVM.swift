import LLVM

extension Symbol {
    func canonicalize() throws -> IRType {
        //FIXME(Brett): throw an error message
        guard let type = self.type else {
            print("ERROR: type is nil")
            return VoidType()
        }
        
        switch source {
        case .native:
            return try type.canonicalized()
            
        case .llvm(let llvmType):
            switch llvmType {
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
                
            default:
                //FIXME(Brett): throw an error message
                print("ERROR: unknown LLVM type: \(llvmType.string)")
                return VoidType()
            }
        }
    }
}
