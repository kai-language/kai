// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension Entity {
    static let void = Entity.makeBuiltin("void", flags: .type)
    static let any = Entity.makeBuiltin("any", flags: .type)
    static let bool = Entity.makeBuiltin("bool", flags: .type)
    static let rawptr = Entity.makeBuiltin("rawptr", flags: .type)
    static let string = Entity.makeBuiltin("string", flags: .type)
    static let f32 = Entity.makeBuiltin("f32", flags: .type)
    static let f64 = Entity.makeBuiltin("f64", flags: .type)
    static let u8 = Entity.makeBuiltin("u8", flags: .type)
    static let i32 = Entity.makeBuiltin("i32", flags: .type)
    static let i64 = Entity.makeBuiltin("i64", flags: .type)
    static let type = Entity.makeBuiltin("type", flags: .type)
    static let TypeInfo = Entity.makeBuiltin("TypeInfo", flags: .type)
}

extension ty {
    static let void = BuiltinType.void.type
    static let any = BuiltinType.any.type
    static let bool = BuiltinType.bool.type
    static let rawptr = BuiltinType.rawptr.type
    static let string = BuiltinType.string.type
    static let f32 = BuiltinType.f32.type
    static let f64 = BuiltinType.f64.type
    static let u8 = BuiltinType.u8.type
    static let i32 = BuiltinType.i32.type
    static let i64 = BuiltinType.i64.type
    static let type = BuiltinType.type.type
    static let TypeInfo = BuiltinType.TypeInfo.type

    static let builtin: [BuiltinType] = [
        BuiltinType.void,
        BuiltinType.any,
        BuiltinType.bool,
        BuiltinType.rawptr,
        BuiltinType.string,
        BuiltinType.f32,
        BuiltinType.f64,
        BuiltinType.u8,
        BuiltinType.i32,
        BuiltinType.i64,
        BuiltinType.type,
        BuiltinType.TypeInfo,
    ]
}

let builtinFunctions: [BuiltinFunction] = [
]

let builtinEntities: [BuiltinEntity] = [
    BuiltinEntity.trué,
    BuiltinEntity.falsé,
]

let builtins: [Entity] = [
    BuiltinEntity.trué.entity,
    BuiltinEntity.falsé.entity,
    BuiltinType.void.entity,
    BuiltinType.any.entity,
    BuiltinType.bool.entity,
    BuiltinType.rawptr.entity,
    BuiltinType.string.entity,
    BuiltinType.f32.entity,
    BuiltinType.f64.entity,
    BuiltinType.u8.entity,
    BuiltinType.i32.entity,
    BuiltinType.i64.entity,
    BuiltinType.type.entity,
    BuiltinType.TypeInfo.entity,
]

