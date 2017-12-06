// Generated using Sourcery 0.9.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension Entity {
    static let void = Entity.makeBuiltin("void", flags: .type)
    static let any = Entity.makeBuiltin("any", flags: .type)
    static let bool = Entity.makeBuiltin("bool", flags: .type)
    static let rawptr = Entity.makeBuiltin("rawptr", flags: .type)
    static let string = Entity.makeBuiltin("string", flags: .type)
    static let f32 = Entity.makeBuiltin("f32", flags: .type)
    static let f64 = Entity.makeBuiltin("f64", flags: .type)
    static let i8 = Entity.makeBuiltin("i8", flags: .type)
    static let u8 = Entity.makeBuiltin("u8", flags: .type)
    static let i16 = Entity.makeBuiltin("i16", flags: .type)
    static let u16 = Entity.makeBuiltin("u16", flags: .type)
    static let i32 = Entity.makeBuiltin("i32", flags: .type)
    static let u32 = Entity.makeBuiltin("u32", flags: .type)
    static let i64 = Entity.makeBuiltin("i64", flags: .type)
    static let u64 = Entity.makeBuiltin("u64", flags: .type)
    static let type = Entity.makeBuiltin("type", flags: .type)
    static let typeInfo = Entity.makeBuiltin("typeInfo", flags: .type)
    static let booleanType = Entity.makeBuiltin("booleanType", flags: .type)
    static let integerType = Entity.makeBuiltin("integerType", flags: .type)
    static let floatType = Entity.makeBuiltin("floatType", flags: .type)
    static let untypedNil = Entity.makeBuiltin("nil", flags: .type)
}

extension ty {
    static let void = BuiltinType.void.type
    static let any = BuiltinType.any.type
    static let bool = BuiltinType.bool.type
    static let rawptr = BuiltinType.rawptr.type
    static let string = BuiltinType.string.type
    static let f32 = BuiltinType.f32.type
    static let f64 = BuiltinType.f64.type
    static let i8 = BuiltinType.i8.type
    static let u8 = BuiltinType.u8.type
    static let i16 = BuiltinType.i16.type
    static let u16 = BuiltinType.u16.type
    static let i32 = BuiltinType.i32.type
    static let u32 = BuiltinType.u32.type
    static let i64 = BuiltinType.i64.type
    static let u64 = BuiltinType.u64.type
    static let untypedInteger = BuiltinType.untypedInteger.type
    static let untypedFloat = BuiltinType.untypedFloat.type
    static let untypedNil = BuiltinType.untypedNil.type
    static let type = BuiltinType.type.type
    static let typeInfo = BuiltinType.typeInfo.type
    static let booleanType = BuiltinType.booleanType.type
    static let integerType = BuiltinType.integerType.type
    static let floatType = BuiltinType.floatType.type

    static let builtin: [BuiltinType] = [
        BuiltinType.void,
        BuiltinType.any,
        BuiltinType.bool,
        BuiltinType.rawptr,
        BuiltinType.string,
        BuiltinType.f32,
        BuiltinType.f64,
        BuiltinType.i8,
        BuiltinType.u8,
        BuiltinType.i16,
        BuiltinType.u16,
        BuiltinType.i32,
        BuiltinType.u32,
        BuiltinType.i64,
        BuiltinType.u64,
        BuiltinType.untypedInteger,
        BuiltinType.untypedFloat,
        BuiltinType.untypedNil,
        BuiltinType.type,
        BuiltinType.typeInfo,
        BuiltinType.booleanType,
        BuiltinType.integerType,
        BuiltinType.floatType,
    ]
}

let builtinFunctions: [BuiltinFunction] = [
    BuiltinFunction.sizeof,
    BuiltinFunction.typeof,
]

let builtinEntities: [BuiltinEntity] = [
    BuiltinEntity.trué,
    BuiltinEntity.falsé,
]

let builtins: [Entity] = [
    BuiltinFunction.sizeof.entity,
    BuiltinFunction.typeof.entity,
    BuiltinEntity.trué.entity,
    BuiltinEntity.falsé.entity,
    BuiltinType.void.entity,
    BuiltinType.any.entity,
    BuiltinType.bool.entity,
    BuiltinType.rawptr.entity,
    BuiltinType.string.entity,
    BuiltinType.f32.entity,
    BuiltinType.f64.entity,
    BuiltinType.i8.entity,
    BuiltinType.u8.entity,
    BuiltinType.i16.entity,
    BuiltinType.u16.entity,
    BuiltinType.i32.entity,
    BuiltinType.u32.entity,
    BuiltinType.i64.entity,
    BuiltinType.u64.entity,
    BuiltinType.untypedInteger.entity,
    BuiltinType.untypedFloat.entity,
    BuiltinType.untypedNil.entity,
    BuiltinType.type.entity,
    BuiltinType.typeInfo.entity,
    BuiltinType.booleanType.entity,
    BuiltinType.integerType.entity,
    BuiltinType.floatType.entity,
]

