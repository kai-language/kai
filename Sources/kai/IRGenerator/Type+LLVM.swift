import LLVM

extension Type {
    func canonicalized() -> IRType {
        switch self.kind {
        case .named(let typeName):
            switch typeName {
            case "void", "unconstrNil":
                return VoidType()

            case "bool", "unconstrBool":
                return IntType.int1

            case "i8", "u8":
                return IntType.int8

            case "i16", "u16":
                return IntType.int16

            case "i32", "u32":
                return IntType.int32

            case "i64", "u64", "int", "uint", "unconstrInteger":
                return IntType.int64

            case "f32":
                return FloatType.float

            case "f64", "unconstrFloat":
                return FloatType.double

            case "string", "unconstrString":
                return PointerType(pointee: IntType.int8)

            default:
                unimplemented("Type emission for type \(self)")
            }
            
        case .alias(_, let type):
            return type.canonicalized()

        case .pointer(let underlyingType):
            return PointerType(pointee: underlyingType.canonicalized())
            
        case .proc(let params, let results, let isVariadic):

            let paramTypes: [IRType]
            if isVariadic {
                paramTypes = params.dropLast().map({ $0.type!.canonicalized() })
            } else {
                paramTypes = params.map({ $0.type!.canonicalized() })
            }
            unimplemented("Multiple returns", if: results.count != 1)
            let resultType = results.first!.canonicalized()
            return FunctionType(argTypes: paramTypes, returnType: resultType, isVarArg: isVariadic)
            
        case .struct:
            unimplemented("Structures")

        case .typeInfo:
            unimplemented("Type info")
        }
    }
}

extension Entity {
    func canonicalized() -> IRType {
        switch kind {
        case .type(let type):
            return type.canonicalized()
            
        default:
            return type!.canonicalized()
        }
    }
}
