
import LLVM

struct BuiltinType {
    var entity: Entity
    var type: Type

    init(entity: Entity, type: Type) {
        self.entity = entity
        self.type = type
    }
    static let void = BuiltinType(entity: .void, type: ty.Void() )
    static let any  = BuiltinType(entity: .any,  type: ty.Anyy())

    static let bool = BuiltinType(entity: .bool,    type: ty.Boolean())
    static let rawptr = BuiltinType(entity: .rawptr, type: ty.Pointer(pointeeType: ty.u8))
    static let string = BuiltinType(entity: .string, type: ty.rawptr) // FIXME: String type

    static let f32 = BuiltinType(entity: .f32, type: ty.FloatingPoint(entity: .f32, width: 32))
    static let f64 = BuiltinType(entity: .f64, type: ty.FloatingPoint(entity: .f64, width: 64))
    static let u8  = BuiltinType(entity: .u8,  type: ty.Integer(entity: Entity.u8, width: 8,  isSigned: false))
    static let i32 = BuiltinType(entity: .i32, type: ty.Integer(entity: Entity.i32, width: 32, isSigned: true))
    static let i64 = BuiltinType(entity: .i64, type: ty.Integer(entity: Entity.i64, width: 64, isSigned: true))

    /// - Note: The type type only exists at compile time
    static let type = BuiltinType(entity: .type, type: ty.Metatype(entity: Entity.type, instanceType: ty.Tuple(width: 0, types: [])))

    static let TypeInfo = ty.Struct.make(named: "TypeInfo", builder: stdlib.builder, [
        ("kind", ty.u8), // TODO: Make this an enumeration
        ("name", ty.string),
        ("width", ty.i64),
    ])
}

extension Entity {
    static let anonymous = Entity.makeBuiltin("_")

    // NOTE: Used for builtins with generics
    static let T = Entity.makeBuiltin("T")
    static let U = Entity.makeBuiltin("U")
    static let V = Entity.makeBuiltin("V")
}

extension ty {
    static let invalid  = ty.Invalid.instance
    static let cvargAny = ty.CVarArg.instance
}


// sourcery:noinit
class BuiltinEntity {

    var entity: Entity
    var type: Type
    var gen: (IRBuilder) -> IRValue

    init(entity: Entity, type: Type, gen: @escaping (IRBuilder) -> IRValue) {
        self.entity = entity
        self.type = type
        self.gen = {
            if let value = entity.value {
                return value
            }
            entity.value = gen($0)
            return entity.value!
        }
    }

    init(name: String, type: Type, gen: @escaping (IRBuilder) -> IRValue) {
        let ident = Ident(start: noPos, name: name, entity: nil)
        let entity = Entity(ident: ident, type: type, flags: .none, memberScope: nil, owningScope: nil, value: nil)
        self.entity = entity
        self.type = type
        self.gen = {
            if let value = entity.value {
                return value
            }
            entity.value = gen($0)
            return entity.value!
        }
    }

    static let trué = BuiltinEntity(name: "true", type: ty.bool, gen: { $0.addGlobal("true", initializer: true.asLLVM()) })
    static let falsé = BuiltinEntity(name: "false", type: ty.bool, gen: { $0.addGlobal("false", initializer: false.asLLVM()) })
}

//let polymorphicT = ty.Metatype(instanceType: ty.Polymorphic(width: nil))
//let polymorphicU = ty.Metatype(instanceType: ty.Polymorphic(width: nil))
//let polymorphicV = ty.Metatype(instanceType: ty.Polymorphic(width: nil))

func lookupBuiltinFunction(_ fun: Expr) -> BuiltinFunction? {
    return builtinFunctions.first(where: { $0.entity.name == (fun as? Ident)?.name })
}

// sourcery:noinit
class BuiltinFunction {
    // TODO: Take IRGen too
    typealias Generate = (BuiltinFunction, [Expr], Void) -> IRValue
    typealias CallCheck = (inout Checker, Call) -> Type

    var entity: Entity
    var type: Type
    var generate: Generate
    var irValue: IRValue?

    var onCallCheck: CallCheck?

    init(entity: Entity, generate: @escaping Generate, onCallCheck: CallCheck?) {
        self.entity = entity
        self.type = entity.type!
        self.generate = generate
        self.onCallCheck = onCallCheck
    }

    /// - Note: OutTypes must be metatypes and will be made instance instanceTypes
    static func make(_ name: String, in inTypes: [Type], out outTypes: [Type], isVariadic: Bool = false, gen: @escaping Generate, onCallCheck: CallCheck? = nil) -> BuiltinFunction {
        let returnType = ty.Tuple.make(outTypes.map(ty.Metatype.init))
        let type = ty.Function(entity: .anonymous, node: nil, params: inTypes, returnType: returnType, flags: .none)

        let ident = Ident(start: noPos, name: name, entity: nil)
        let entity = Entity(ident: ident, type: type, flags: .none, memberScope: nil, owningScope: nil, value: nil)

        return BuiltinFunction(entity: entity, generate: gen, onCallCheck: onCallCheck)
    }
}

/*
var typeInfoValues: [Type: IRValue] = [:]
func typeinfoGen(builtinFunction: BuiltinFunction, parameters: [Node], generator: inout IRGenerator) -> IRValue {

    let typeInfoType = Type.typeInfo.asMetatype.instanceType
    let type = parameters[0].exprType.asMetatype.instanceType

    if let global = typeInfoValues[type] {
        return global
    }

    let aggregateType = (canonicalize(typeInfoType)) as! StructType

    let typeKind = unsafeBitCast(type.kind, to: Int8.self)
    let name = builder.buildGlobalStringPtr(type.description)
    let width = type.width ?? 0

    let values: [IRValue] = [typeKind, name, width]
    assert(values.count == typeInfoType.asStruct.fields.count)

    let global = builder.addGlobal("TI(\(type.description))", initializer: aggregateType.constant(values: values))

    typeInfoValues[type] = global
    return global
}
*/
/*
func bitcastGen(builtinFunction: BuiltinFunction, parameters: [Node], generator: inout IRGenerator) -> IRValue {
    assert(parameters.count == 2)

    let input = generator.emitExpr(node: parameters[0], returnAddress: true)
    var outputType = canonicalize(parameters[1].exprType.asMetatype.instanceType)
    outputType = PointerType(pointee: outputType)
    let pointer = builder.buildBitCast(input, type: outputType)
    return builder.buildLoad(pointer)
}
*/
