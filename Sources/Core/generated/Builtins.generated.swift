// Generated using Sourcery 0.9.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension Entity {
    static var void = Entity.makeBuiltin("void", flags: .type)
    static var any = Entity.makeBuiltin("any", flags: .type)
    static var bool = Entity.makeBuiltin("bool", flags: .type)
    static var rawptr = Entity.makeBuiltin("rawptr", flags: .type)
    static var string = Entity.makeBuiltin("string", flags: .type)
    static var f32 = Entity.makeBuiltin("f32", flags: .type)
    static var f64 = Entity.makeBuiltin("f64", flags: .type)
    static var i8 = Entity.makeBuiltin("i8", flags: .type)
    static var u8 = Entity.makeBuiltin("u8", flags: .type)
    static var i16 = Entity.makeBuiltin("i16", flags: .type)
    static var u16 = Entity.makeBuiltin("u16", flags: .type)
    static var i32 = Entity.makeBuiltin("i32", flags: .type)
    static var u32 = Entity.makeBuiltin("u32", flags: .type)
    static var i64 = Entity.makeBuiltin("i64", flags: .type)
    static var u64 = Entity.makeBuiltin("u64", flags: .type)
    static var trué = Entity.makeBuiltin("trué", flags: .type)
    static var falsé = Entity.makeBuiltin("falsé", flags: .type)
    static let untypedNil = Entity.makeBuiltin("nil", flags: .type)
}

extension ty {
    static var void = builtin.globals.void.type
    static var any = builtin.globals.any.type
    static var bool = builtin.globals.bool.type
    static var rawptr = builtin.globals.rawptr.type
    static var string = builtin.globals.string.type
    static var f32 = builtin.globals.f32.type
    static var f64 = builtin.globals.f64.type
    static var i8 = builtin.globals.i8.type
    static var u8 = builtin.globals.u8.type
    static var i16 = builtin.globals.i16.type
    static var u16 = builtin.globals.u16.type
    static var i32 = builtin.globals.i32.type
    static var u32 = builtin.globals.u32.type
    static var i64 = builtin.globals.i64.type
    static var u64 = builtin.globals.u64.type
    static var trué = builtin.globals.trué.type
    static var falsé = builtin.globals.falsé.type
    static let untypedInteger = builtin.untypedInteger.type
    static let untypedFloat   = builtin.untypedFloat.type
    static let untypedNil     = builtin.untypedNil.type
}

var builtinFunctions: [BuiltinFunction] = [
    builtin.types.sizeOf,
    builtin.types.typeOf,
]

var builtinEntities: [BuiltinEntity] = [
    builtin.globals.trué,
    builtin.globals.falsé,
    builtin.platform.pointerWidth,
    builtin.platform.isBigEndian,
    builtin.platform.osTriple,
]

var globalBuiltins: Set<Entity> = {
    return [
        builtin.globals.void.entity,
        builtin.globals.any.entity,
        builtin.globals.bool.entity,
        builtin.globals.rawptr.entity,
        builtin.globals.string.entity,
        builtin.globals.f32.entity,
        builtin.globals.f64.entity,
        builtin.globals.i8.entity,
        builtin.globals.u8.entity,
        builtin.globals.i16.entity,
        builtin.globals.u16.entity,
        builtin.globals.i32.entity,
        builtin.globals.u32.entity,
        builtin.globals.i64.entity,
        builtin.globals.u64.entity,
        builtin.globals.trué.entity,
        builtin.globals.falsé.entity,
    ]
}()


// MARK: Package scopes

// FIXME: @pr Add in the builtin packages. Hopefully after we work out how to auto generate their definitions
var builtinPackages: [String: Scope] = [
    "globals": builtin.globals.scope,
    "platform": builtin.platform.scope,
    "types": builtin.types.scope,
]


extension builtin.globals {

    static let scope: Scope = {
        let members: [String: Entity] = [
            builtin.globals.void.entity,
            builtin.globals.any.entity,
            builtin.globals.bool.entity,
            builtin.globals.rawptr.entity,
            builtin.globals.string.entity,
            builtin.globals.f32.entity,
            builtin.globals.f64.entity,
            builtin.globals.i8.entity,
            builtin.globals.u8.entity,
            builtin.globals.i16.entity,
            builtin.globals.u16.entity,
            builtin.globals.i32.entity,
            builtin.globals.u32.entity,
            builtin.globals.i64.entity,
            builtin.globals.u64.entity,
            builtin.globals.trué.entity,
            builtin.globals.falsé.entity,
        ].toDictionary(with: { $0.name })
        return Scope(parent: .global, owningNode: nil, isFile: false, isPackage: true, members: members)
    }()
}

extension builtin.platform {

    static let scope: Scope = {
        let members: [String: Entity] = [
            builtin.platform.pointerWidth.entity,
            builtin.platform.isBigEndian.entity,
            builtin.platform.osTriple.entity,
        ].toDictionary(with: { $0.name })
        return Scope(parent: .global, owningNode: nil, isFile: false, isPackage: true, members: members)
    }()
}

extension builtin.types {

    static let scope: Scope = {
        let members: [String: Entity] = [
            builtin.types.typeInfo.entity,
            builtin.types.boolean.entity,
            builtin.types.integer.entity,
            builtin.types.float.entity,
            builtin.types.any.entity,
            builtin.types.compound.entity,
            builtin.types.pointer.entity,
            builtin.types.slice.entity,
            builtin.types.array.entity,
            builtin.types.vector.entity,
            builtin.types.`struct`.entity,
            builtin.types.union.entity,
            builtin.types.`enum`.entity,
            builtin.types.named.entity,
            builtin.types.sizeOf.entity,
            builtin.types.typeOf.entity,
        ].toDictionary(with: { $0.name })
        return Scope(parent: .global, owningNode: nil, isFile: false, isPackage: true, members: members)
    }()
}
