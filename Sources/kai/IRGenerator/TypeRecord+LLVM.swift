import LLVM

extension TypeRecord {

    func canonicalized() throws -> IRType {
        // if we already have a llvm type generated, use that.
        if let llvm = self.llvm { return llvm }

        switch self.kind {
        case .basic(let basicType):
            switch basicType.kind {
            case .invalid:
                fatalError("invalid types should result in an abortion prior to calling \(#function)")

            case .void:
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
                fatalError("Unconstrained types should be transformed at the sight of their use.")
                // TODO(vdka): This isn't compatible with distributing binaries.
                //   It only works in a whole module sense I guess you could say. Not good.
            }

        default:
            unimplemented("Currently we are limitted to canonicalizing basic types")
        }
    }
}
