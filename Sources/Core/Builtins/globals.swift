
import LLVM

extension Scope {

    static let global: Scope = {

        return Scope(members: globalBuiltins.toDictionary(with: { $0.name }))
    }()
}

extension builtin {

    /// - Note: The namespacing here is used by code gen to generate things that are to be inserted into the global scope.
    enum globals {

        static let void = BuiltinType(entity: .void, type: ty.Void())
        static let any  = BuiltinType(entity: .any,  type: ty.Anyy())

        static let bool   = BuiltinType(entity: .bool,   type: ty.Boolean(width: 1))
        static let rawptr = BuiltinType(entity: .rawptr, type: ty.Pointer(u8.type))
        static let string = BuiltinType(entity: .string, type: ty.Slice(elementType: u8.type))

        static let f32 = BuiltinType(entity: .f32, type: ty.FloatingPoint(width: 32))
        static let f64 = BuiltinType(entity: .f64, type: ty.FloatingPoint(width: 64))

        static let i8  = BuiltinType(entity: .i8,  type: ty.Integer(width: 8,  isSigned: true))
        static let u8  = BuiltinType(entity: .u8,  type: ty.Integer(width: 8,  isSigned: false))
        static let i16 = BuiltinType(entity: .i16, type: ty.Integer(width: 16, isSigned: true))
        static let u16 = BuiltinType(entity: .u16, type: ty.Integer(width: 16, isSigned: false))
        static let i32 = BuiltinType(entity: .i32, type: ty.Integer(width: 32, isSigned: true))
        static let u32 = BuiltinType(entity: .u32, type: ty.Integer(width: 32, isSigned: false))
        static let i64 = BuiltinType(entity: .i64, type: ty.Integer(width: 64, isSigned: true))
        static let u64 = BuiltinType(entity: .u64, type: ty.Integer(width: 64, isSigned: false))

        // FIXME: For builtin entities we need to allow the desired type to propigate the correct boolean type into here, in case it's a non 1 width boolean
        static let trué: BuiltinEntity = BuiltinEntity(name: "true", type: bool.type, gen: { IntType(width: 1, in: $0.module.context).constant(1) })
        static let falsé: BuiltinEntity = BuiltinEntity(name: "false", type: bool.type, gen: { IntType(width: 1, in: $0.module.context).constant(0) })
    }
}
