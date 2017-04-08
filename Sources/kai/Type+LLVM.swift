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

        case .pointer(let underlyingType),
             .nullablePointer(let underlyingType):
            return PointerType(pointee: underlyingType.canonicalized())

        case .array(let underlyingType, let count):
            return ArrayType(elementType: underlyingType.canonicalized(), count: Int(count))
            
        case .proc(let params, let results, let isVariadic):

            let paramTypes: [IRType]
            if isVariadic {
                paramTypes = params.dropLast().map({ $0.type!.canonicalized() })
            } else {
                paramTypes = params.map({ $0.type!.canonicalized() })
            }

            let resultType: IRType

            if results.count == 1, let firstResult = results.first {

                resultType = firstResult.canonicalized()
            } else {

                let resultIrTypes = results.map({ $0.canonicalized() })
                resultType = StructType(elementTypes: resultIrTypes)
            }

            return FunctionType(argTypes: paramTypes, returnType: resultType, isVarArg: isVariadic)
            
        case .struct:
            unimplemented("Structures")

        case .tuple(let types):
            return StructType(elementTypes: types.map({ $0.canonicalized() }))

        case .typeInfo:
            unimplemented("Type info")
        }
    }
}
