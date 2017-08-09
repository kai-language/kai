
import LLVM

struct BuiltinType {

    var entity: Entity
    var type: Type

    init(name: String, type: Type) {

        self.type = type
        self.entity = Entity.makeBuiltin(name, type: ty.Metatype(instanceType: type))
        entity.flags.insert(.type)
    }

    static let void = BuiltinType(name: "void", type: ty.Void())
    static let type = BuiltinType(name: "type", type: ty.Void())
    static let any  = BuiltinType(name: "any",  type: ty.Anyy())

    static let bool = BuiltinType(name: "bool",     type: ty.Boolean())
    static let rawptr = BuiltinType(name: "rawptr", type: ty.Pointer(pointeeType: ty.u8))
    static let string = BuiltinType(name: "string", type: ty.rawptr)

    static let f32 = BuiltinType(name: "f32", type: ty.FloatingPoint())
    static let f64 = BuiltinType(name: "f64", type: ty.FloatingPoint())
    static let u8  = BuiltinType(name: "u8",  type: ty.Integer(width: 8,  isSigned: false))
    static let i32 = BuiltinType(name: "i32", type: ty.Integer(width: 32, isSigned: true))
    static let i64 = BuiltinType(name: "i64", type: ty.Integer(width: 64, isSigned: true))
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

let typeInfoTy = ty.Struct.make(named: "TypeInfo", builder: stdlib.builder, [
    ("kind", ty.u8), // TODO: Make this an enumeration
    ("name", ty.string),
    ("width", ty.i64),
])


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

let polymorphicT = ty.Metatype(instanceType: ty.Polymorphic(width: nil))
let polymorphicU = ty.Metatype(instanceType: ty.Polymorphic(width: nil))
let polymorphicV = ty.Metatype(instanceType: ty.Polymorphic(width: nil))

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
        let type = ty.Function(width: nil, node: nil, params: inTypes, returnType: returnType, flags: .none)

        let ident = Ident(start: noPos, name: name, entity: nil)
        let entity = Entity(ident: ident, type: type, flags: .none, memberScope: nil, owningScope: nil, value: nil)

        return BuiltinFunction(entity: entity, generate: gen, onCallCheck: onCallCheck)
    }
}

