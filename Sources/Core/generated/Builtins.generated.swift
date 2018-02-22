// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


extension Entity {
    static var void = Entity.makeBuiltin("void", flags: .type)
    static var any = Entity.makeBuiltin("any", flags: .type)
    static var bool = Entity.makeBuiltin("bool", flags: .type)
    static var rawptr = Entity.makeBuiltin("rawptr", flags: .type)
    static var string = Entity.makeBuiltin("string", flags: .type)
    static var f32 = Entity.makeBuiltin("f32", flags: .type)
    static var f64 = Entity.makeBuiltin("f64", flags: .type)
    static var b8 = Entity.makeBuiltin("b8", flags: .type)
    static var b16 = Entity.makeBuiltin("b16", flags: .type)
    static var b32 = Entity.makeBuiltin("b32", flags: .type)
    static var b64 = Entity.makeBuiltin("b64", flags: .type)
    static var i8 = Entity.makeBuiltin("i8", flags: .type)
    static var i16 = Entity.makeBuiltin("i16", flags: .type)
    static var i32 = Entity.makeBuiltin("i32", flags: .type)
    static var i64 = Entity.makeBuiltin("i64", flags: .type)
    static var u8 = Entity.makeBuiltin("u8", flags: .type)
    static var u16 = Entity.makeBuiltin("u16", flags: .type)
    static var u32 = Entity.makeBuiltin("u32", flags: .type)
    static var u64 = Entity.makeBuiltin("u64", flags: .type)
    static var trué = Entity.makeBuiltin("trué", flags: .type)
    static var falsé = Entity.makeBuiltin("falsé", flags: .type)
}

extension ty {
    static var void = builtin.globals.void.type
    static var any = builtin.globals.any.type
    static var bool = builtin.globals.bool.type
    static var rawptr = builtin.globals.rawptr.type
    static var string = builtin.globals.string.type
    static var f32 = builtin.globals.f32.type
    static var f64 = builtin.globals.f64.type
    static var b8 = builtin.globals.b8.type
    static var b16 = builtin.globals.b16.type
    static var b32 = builtin.globals.b32.type
    static var b64 = builtin.globals.b64.type
    static var i8 = builtin.globals.i8.type
    static var i16 = builtin.globals.i16.type
    static var i32 = builtin.globals.i32.type
    static var i64 = builtin.globals.i64.type
    static var u8 = builtin.globals.u8.type
    static var u16 = builtin.globals.u16.type
    static var u32 = builtin.globals.u32.type
    static var u64 = builtin.globals.u64.type
    static var trué = builtin.globals.trué.type
    static var falsé = builtin.globals.falsé.type
    static let untypedInteger = builtin.untypedInteger.type
    static let untypedFloat   = builtin.untypedFloat.type
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
    builtin.types.flagUntyped,
    builtin.types.flagSigned,
    builtin.types.flagVector,
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
        builtin.globals.b8.entity,
        builtin.globals.b16.entity,
        builtin.globals.b32.entity,
        builtin.globals.b64.entity,
        builtin.globals.i8.entity,
        builtin.globals.i16.entity,
        builtin.globals.i32.entity,
        builtin.globals.i64.entity,
        builtin.globals.u8.entity,
        builtin.globals.u16.entity,
        builtin.globals.u32.entity,
        builtin.globals.u64.entity,
        builtin.globals.trué.entity,
        builtin.globals.falsé.entity,
    ]
}()


// MARK: Package scopes

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
            builtin.globals.b8.entity,
            builtin.globals.b16.entity,
            builtin.globals.b32.entity,
            builtin.globals.b64.entity,
            builtin.globals.i8.entity,
            builtin.globals.i16.entity,
            builtin.globals.i32.entity,
            builtin.globals.i64.entity,
            builtin.globals.u8.entity,
            builtin.globals.u16.entity,
            builtin.globals.u32.entity,
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
            builtin.types.simple.entity,
            builtin.types.boolean.entity,
            builtin.types.integer.entity,
            builtin.types.float.entity,
            builtin.types.any.entity,
            builtin.types.void.entity,
            builtin.types.array.entity,
            builtin.types.pointer.entity,
            builtin.types.slice.entity,
            builtin.types.function.entity,
            builtin.types.`struct`.entity,
            builtin.types.structField.entity,
            builtin.types.union.entity,
            builtin.types.unionCase.entity,
            builtin.types.`enum`.entity,
            builtin.types.enumCase.entity,
            builtin.types.named.entity,
            builtin.types.flagUntyped.entity,
            builtin.types.flagSigned.entity,
            builtin.types.flagVector.entity,
            builtin.types.sizeOf.entity,
            builtin.types.typeOf.entity,
        ].toDictionary(with: { $0.name })
        return Scope(parent: .global, owningNode: nil, isFile: false, isPackage: true, members: members)
    }()
}


extension builtin.types {

    static var typeInfoType: Type { return builtin.types.typeInfo.type }
    static var simpleType: Type { return builtin.types.simple.type }
    static var booleanType: Type { return builtin.types.boolean.type }
    static var integerType: Type { return builtin.types.integer.type }
    static var floatType: Type { return builtin.types.float.type }
    static var anyType: Type { return builtin.types.any.type }
    static var voidType: Type { return builtin.types.void.type }
    static var arrayType: Type { return builtin.types.array.type }
    static var pointerType: Type { return builtin.types.pointer.type }
    static var sliceType: Type { return builtin.types.slice.type }
    static var functionType: Type { return builtin.types.function.type }
    static var structType: Type { return builtin.types.`struct`.type }
    static var structFieldType: Type { return builtin.types.structField.type }
    static var unionType: Type { return builtin.types.union.type }
    static var unionCaseType: Type { return builtin.types.unionCase.type }
    static var enumType: Type { return builtin.types.`enum`.type }
    static var enumCaseType: Type { return builtin.types.enumCase.type }
    static var namedType: Type { return builtin.types.named.type }
    static var flagUntypedType: Type { return builtin.types.flagUntyped.type }
    static var flagSignedType: Type { return builtin.types.flagSigned.type }
    static var flagVectorType: Type { return builtin.types.flagVector.type }
    static var sizeOfType: Type { return builtin.types.sizeOf.type }
    static var typeOfType: Type { return builtin.types.typeOf.type }
}
