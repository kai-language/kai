
import LLVM

var platformPointerWidth: Int = {
    return targetMachine.dataLayout.pointerSize() * 8
}()

struct BuiltinType {
    var entity: Entity
    var type: Type

    init(entity: Entity, type: Type) {
        entity.flags.insert(.builtin)
        self.entity = entity
        self.type = type
    }

    init(entity: Entity, type: NamableType) {
        entity.flags.insert(.builtin)
        self.entity = entity
        self.type = ty.Named(entity: entity, base: type)
        entity.type = type
    }
    static let void = BuiltinType(entity: .void, type: ty.Void())
    static let any  = BuiltinType(entity: .any,  type: ty.Anyy())

    static let bool = BuiltinType(entity:   .bool,   type: ty.Boolean())
    static let rawptr = BuiltinType(entity: .rawptr, type: ty.Pointer(pointeeType: ty.u8))
    static let string = BuiltinType(entity: .string, type: ty.Slice(elementType: ty.u8))

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

    static let untypedInteger = BuiltinType(entity: .anonymous, type: ty.UntypedInteger())
    static let untypedFloat   = BuiltinType(entity: .anonymous, type: ty.UntypedFloatingPoint())
    static let untypedNil     = BuiltinType(entity: .untypedNil, type: ty.UntypedNil())

    /// - Note: The type type only exists at compile time
    static let type = BuiltinType(entity: .type, type: ty.Metatype(instanceType: ty.Tuple(width: 0, types: [])))

    // FIXME: Add these to the types packages
    static let typeInfo = ty.Union.make(name: "Type", [
        ("Tag", ty.Integer(width: 3, isSigned: false)),
        ("Compound", ty.rawptr), // platform width is max width here
        ("Boolean", ty.booleanType),
        ("Integer", ty.integerType),
        ("Float", ty.floatType),
    ])

    static let booleanType = ty.Struct.make(name: "Boolean", [
        ("Tag", ty.Integer(width: 3, isSigned: false)),
        ("Width", ty.Integer(width: 61, isSigned: false)),
    ])

    // TODO: Communicate signedness
    static let integerType = ty.Struct.make(name: "Integer", [
        ("Tag", ty.Integer(width: 3, isSigned: false)),
        ("Signed", ty.Boolean()),
        ("Width", ty.Integer(width: 60, isSigned: false)),
    ])

    static let floatType = ty.Struct.make(name: "Float", [
        ("Tag", ty.Integer(width: 3, isSigned: false)),
        ("Width", ty.Integer(width: 61, isSigned: false)),
    ])

//    static let TypeInfo = ty.Struct.make(named: "TypeInfo", builder: stdlib.builder, [
//        ("kind", ty.u8), // TODO: Make this an enumeration
//        ("name", ty.string),
//        ("width", ty.i64),
//    ])
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
        let ident = Ident(start: noPos, name: name, entity: nil, type: nil, conversion: nil, constant: nil)
        let entity = Entity(ident: ident, type: type, flags: .builtin, constant: nil, file: nil, memberScope: nil, owningScope: nil, callconv: nil, linkname: nil, mangledName: nil, value: nil)
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

    static let trué = BuiltinEntity(name: "true", type: ty.bool, gen: { b in IntType(width: 1, in: b.module.context).constant(1) })
    static let falsé = BuiltinEntity(name: "false", type: ty.bool, gen: { b in IntType(width: 1, in: b.module.context).constant(0) })
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
    typealias Generate = (BuiltinFunction, [Expr], inout IRGenerator) -> IRValue
    typealias CallCheck = (inout Checker, Call) -> Type

    var entity: Entity
    var type: Type
    var generate: Generate
    var irValue: IRValue?

    var onCallCheck: CallCheck?

    init(entity: Entity, generate: @escaping Generate, onCallCheck: CallCheck?) {
        entity.flags.insert(.builtin)
        self.entity = entity
        self.type = entity.type!
        self.generate = generate
        self.onCallCheck = onCallCheck
    }

    /// - Note: OutTypes must be metatypes and will be made instance instanceTypes
    static func make(_ name: String, in inTypes: [Type], out outTypes: [Type], isVariadic: Bool = false, gen: @escaping Generate, onCallCheck: CallCheck? = nil) -> BuiltinFunction {
        let returnType = ty.Tuple.make(outTypes.map(ty.Metatype.init))
        let type = ty.Function(node: nil, labels: nil, params: inTypes, returnType: returnType, flags: .none)

        let ident = Ident(start: noPos, name: name, entity: nil, type: nil, conversion: nil, constant: nil)
        let entity = Entity(ident: ident, type: type)

        return BuiltinFunction(entity: entity, generate: gen, onCallCheck: onCallCheck)
    }

    static let sizeof = BuiltinFunction(
        entity: Entity.makeBuiltin("sizeof", type: ty.Function.make([ty.any], [ty.untypedInteger])),
        generate: { function, exprs, gen in
            var type = exprs[0].type!
            if let meta = type as? ty.Metatype {
                type = meta.instanceType
            }
            let irType = gen.canonicalize(type)
            // TODO: Ensure the integer returned matches the `untypedInteger` types width.
            return gen.b.buildSizeOf(irType)
        }, onCallCheck: nil
    )

    static let typeof = BuiltinFunction(
        entity: Entity.makeBuiltin("typeof", type: ty.Function.make([ty.any], [ty.typeInfo])), generate: { function, exprs, gen in
            var type = baseType(exprs[0].type!) // FIXME: Don't unwrap named types

            let (info, boolean, integer, floatingPoint) = generateTypeInfoLLVM(&gen)
            let tag = typeInfoTag(for: type)
            let value: IRValue
            switch type {
            case let type as ty.Boolean:
                value = boolean.constant(values: [gen.i3.constant(tag), gen.i61.constant(type.width!)])

            case let type as ty.Integer:
                // Tag, Signed, Width
                value = integer.constant(values: [gen.i3.constant(tag), gen.i1.constant(type.isSigned ? 1 : 0), gen.i60.constant(type.width!)])

            case let type as ty.FloatingPoint:
                value = floatingPoint.constant(values: [gen.i3.constant(tag), gen.i61.constant(type.width!)])

            default:
                fatalError()
            }

            let stackPtr = gen.b.buildAlloca(type: value.type)
            gen.b.buildStore(value, to: stackPtr)
            let ptr = gen.b.buildBitCast(stackPtr, type: LLVM.PointerType(pointee: info))
            return gen.b.buildLoad(ptr)
        }, onCallCheck: { (checker, call) in
            guard call.args.count == 1 else {
                checker.reportError("Expected 1 argument in call to 'typeInfo'", at: call.start)
                return ty.invalid
            }

            _ = checker.check(expr: call.args[0])

            return ty.typeInfo
        }
    )
}

extension IRBuilder {
    @discardableResult
    func buildMemcpy(_ dest: IRValue, _ source: IRValue, count: IRValue, alias: Int = 1) -> IRValue {
        let memcpy: Function
        if let function = module.function(named: "llvm.memcpy.p0i8.p0i8.i64") {
            memcpy = function
        } else {
            let rawptr = LLVM.PointerType(pointee: IntType(width: 8, in: module.context))
            let memcpyType = FunctionType(
                argTypes: [rawptr, rawptr, IntType(width: 64, in: module.context), IntType(width: 32, in: module.context), IntType(width: 1, in: module.context)], returnType: VoidType(in: module.context)
            )
            memcpy = addFunction("llvm.memcpy.p0i8.p0i8.i64", type: memcpyType)
        }

        return buildCall(memcpy,
                         args: [dest, source, count, IntType(width: 32, in: module.context).constant(alias), IntType(width: 1, in: module.context).constant(0)]
        )
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
