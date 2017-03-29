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
            
        case .proc:
            unimplemented("Procedures")
            
        case .struct:
            unimplemented("Structures")

        case .typeInfo:
            unimplemented("Type info")
            
            /*case .void:
                return VoidType()

            case .bool:
                return IntType.int1

            case .i8, .u8:
                return IntType.int8

            case .i16, .u16:
                return IntType.int16

            case .i32, .u32:
                return IntType.int32

            case .i64, .u64:
                return IntType.int64

            case .f32:
                return FloatType.float

            case .f64:
                return FloatType.double


            // TODO(vdka): Platform native size.
            // make sure to update the TypeRecord with their width
            case .int, .uint:
                return IntType.int64

            case .rawptr:
                return PointerType.toVoid

            case .string:
                return PointerType(pointee: IntType.int8)

            case .unconstrained(_):
                fatalError("Unconstrained types should be transformed at the site of their use.")
                // TODO(vdka): This isn't compatible with distributing binaries.
                //   It only works in a whole module sense I guess you could say. Not good.
            */
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
