
import LLVM

var platformPointerWidth: Int = {
    return targetMachine.dataLayout.pointerSize() * 8
}()

func performAllPackageTypePatches() {
    builtin.types.patchTypes()
}

enum builtin {

    static let untypedInteger = BuiltinType(entity: .anonymous, type: ty.UntypedInteger())
    static let untypedFloat   = BuiltinType(entity: .anonymous, type: ty.UntypedFloat())
    static let untypedNil     = BuiltinType(entity: .untypedNil, type: ty.UntypedNil())

    /// - Note: The type type only exists at compile time
//    static let type = BuiltinType(entity: .type, type: ty.Metatype(instanceType: ty.Tuple(width: 0, types: [])))
}

struct BuiltinType {
    var entity: Entity
    var type: Type

    init(entity: Entity, type: Type) {
        entity.flags.insert(.builtin)
        self.entity = entity
        self.type = type
        entity.type = ty.Metatype(instanceType: type)
    }

    init(entity: Entity, type: NamableType) {
        entity.flags.insert(.builtin)
        self.entity = entity
        self.type = ty.Named(entity: entity, base: type)
        entity.type = ty.Metatype(instanceType: self.type)
    }
}

extension Entity {
    static let anonymous = Entity.makeBuiltin("_")
}

extension ty {
    static let invalid  = ty.Invalid.instance
}


// sourcery:noinit
class BuiltinEntity {

    var entity: Entity
    var type: Type
    var gen: (inout IRGenerator) -> IRValue

    init(entity: Entity, type: Type, gen: @escaping (inout IRGenerator) -> IRValue) {
        self.entity = entity
        self.type = type
        self.gen = {
            if let value = entity.value {
                return value
            }
            entity.value = gen(&$0)
            return entity.value!
        }
    }

    init(name: String, type: Type, gen: @escaping (inout IRGenerator) -> IRValue) {
        let ident = Ident(start: noPos, name: name)
        let entity = Entity(ident: ident, type: type, flags: .builtin)
        self.entity = entity
        self.type = type
        self.gen = {
            if let value = entity.value {
                return value
            }
            entity.value = gen(&$0)
            return entity.value!
        }
    }
}

//let polymorphicT = ty.Metatype(instanceType: ty.Polymorphic(width: nil))
//let polymorphicU = ty.Metatype(instanceType: ty.Polymorphic(width: nil))
//let polymorphicV = ty.Metatype(instanceType: ty.Polymorphic(width: nil))

// sourcery:noinit
class BuiltinFunction {
    // FIXME: right now we can only _call_ to builtin functions, refering to them without calling them will crash as their entities have no value!
    typealias Generate = (BuiltinFunction, _ returnAddress: Bool, [Expr], inout IRGenerator) -> IRValue
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

        let ident = Ident(start: noPos, name: name)
        let entity = Entity(ident: ident, type: type)

        return BuiltinFunction(entity: entity, generate: gen, onCallCheck: onCallCheck)
    }
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

extension Entity {

    static func makeBuiltin(_ name: String, type: Type? = nil, flags: Flag = .none) -> Entity {

        let ident = Ident(start: noPos, name: name)
        let entity = Entity(ident: ident, type: type, flags: flags)
        return entity
    }
}

extension BuiltinType {

    /// Makes a builtin struct in the builtin package named by `package` or in the global scope if package is nil
    init(name: String, flags: ty.Struct.Flags = .none, structMembers: [(String, Type)]) {
        var width = 0
        var fields: [ty.Struct.Field] = []
        for (index, (name, type)) in structMembers.enumerated() {
            let ident = Ident(start: noPos, name: name)
            let field = ty.Struct.Field(ident: ident, type: type, index: index, offset: width)
            fields.append(field)
            width = (width + type.width!)
//                width = (width + type.width!).round(upToNearest: 8)
        }

        let entity = Entity.makeBuiltin(name)
        let type = ty.Struct(width: width, flags: flags, node: Empty(semicolon: noPos, isImplicit: true), fields: fields)

        entity.type = type
        self.init(entity: entity, type: type)
    }
}

extension BuiltinType {

    /// Makes a builtin union in the builtin package named by `package` or in the global scope if package is nil
    init(name: String, flags: ty.Union.Flags = .none, tagWidth: Int? = nil, unionMembers: [(String, Type)]) {
        var width = 0
        var cases: [ty.Union.Case] = []
        for (index, (name, type)) in unionMembers.enumerated() {
            let ident = Ident(start: noPos, name: name)
            let c = ty.Union.Case(ident: ident, type: type, tag: index)
            cases.append(c)
            width = max(width, type.width!)
        }

        let entity = Entity.makeBuiltin(name)

        let tagWidth = tagWidth ?? unionMembers.count.bitsNeeded()

        if !flags.contains(.inlineTag) {
            width += tagWidth
        }

        let type = ty.Union(width: width, tagWidth: tagWidth, flags: flags, cases: cases)

        entity.type = type
        self.init(entity: entity, type: type)
    }

    /// Makes a builtin union in the builtin package named by `package` or in the global scope if package is nil
    init(name: String, flags: ty.Union.Flags = .none, tagWidth: Int? = nil, unionMembers: [(String, Type, Int)]) {
        var width = 0
        var cases: [ty.Union.Case] = []
        for (name, type, tag) in unionMembers {
            let ident = Ident(start: noPos, name: name)
            let c = ty.Union.Case(ident: ident, type: type, tag: tag)
            cases.append(c)
            width = max(width, type.width!)
        }

        let entity = Entity.makeBuiltin(name)

        let tagWidth = tagWidth ?? unionMembers.count.bitsNeeded()

        if !flags.contains(.inlineTag) {
            width += tagWidth
        }

        let type = ty.Union(width: width, tagWidth: tagWidth, flags: flags, cases: cases)

        entity.type = type
        self.init(entity: entity, type: type)
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
