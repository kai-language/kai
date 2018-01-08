
import LLVM

extension builtin {

    /// - Note: This contains the entities used in the types builtin package
    enum types {

        // - MARK: Types

        static var typeInfo: BuiltinType = BuiltinType(name: "Type", unionMembers: [
            ("Tag", ty.Integer(width: 3, isSigned: false)),
            ("Compound", ty.rawptr),        // NOTE: This is made a typed pointer after the compound type is fully created. See `patchTypesPackageCompoundPointer`
            ("Boolean", builtin.types.boolean.type),
            ("Integer", builtin.types.integer.type),
            ("Float", builtin.types.float.type),
        ])

        static let boolean: BuiltinType = BuiltinType(name: "Boolean", structMembers: [
            ("reserved", ty.Integer(width: 32, isSigned: false)),
            ("Width", ty.Integer(width: 32, isSigned: false)),
        ])

        static let integer: BuiltinType = BuiltinType(name: "Integer", structMembers: [
            ("reserved", ty.Integer(width: 31, isSigned: false)),
            ("Signed", ty.Boolean()),
            ("Width", ty.Integer(width: 32, isSigned: false)),
        ])

        static let float: BuiltinType = BuiltinType(name: "Float", structMembers: [
            ("reserved", ty.Integer(width: 32, isSigned: false)),
            ("Width", ty.Integer(width: 32, isSigned: false)),
        ])

        static let any: BuiltinType = BuiltinType(name: "Any", structMembers: [
            ("reserved", ty.Integer(width: 64, isSigned: false)),
        ])


        // MARK: Compound Types

        static var compound: BuiltinType = BuiltinType(name: "Compound", unionMembers: [
            ("Pointer", builtin.types.pointer.type),
            ("Slice", builtin.types.slice.type),
            ("Array", builtin.types.array.type),
            ("Vector", builtin.types.vector.type),
            ("Struct", builtin.types.struct.type),
            ("Union", builtin.types.union.type),
            ("Enum", builtin.types.enum.type),
            ("Named", builtin.types.named.type),
        ])

        static let pointer: BuiltinType = BuiltinType(name: "Pointer", structMembers: [
            ("Type", builtin.types.typeInfo.type),
        ])

        static let slice: BuiltinType = BuiltinType(name: "Slice", structMembers: [
            ("Type", builtin.types.typeInfo.type),
        ])

        static let array: BuiltinType = BuiltinType(name: "Array", structMembers: [
            ("Type", builtin.types.typeInfo.type),
            ("Size", ty.Integer(width: 61, isSigned: false)),
        ])

        static let vector: BuiltinType = BuiltinType(name: "Vector", structMembers: [
            ("Type", builtin.types.typeInfo.type),
            ("Size", ty.Integer(width: 64, isSigned: false)),
        ])

        static let `struct`: BuiltinType = BuiltinType(name: "Struct", structMembers: [
            ("Flags", ty.Integer(width: 64, isSigned: false)),
            ("Names", ty.Slice(elementType: ty.string)),
            ("Types", ty.Slice(elementType: builtin.types.typeInfo.type)),
            ("Offsets", ty.Slice(elementType: ty.u64)),
        ])

        static let union: BuiltinType = BuiltinType(name: "Union", structMembers: [
            ("Flags", ty.Integer(width: 61, isSigned: false)),
            ("Types", ty.Slice(elementType: builtin.types.typeInfo.type)),
        ])

        static let `enum`: BuiltinType = BuiltinType(name: "Enum", structMembers: [
            ("BaseType", ty.Pointer(pointeeType: builtin.types.typeInfo.type)),
            ("Names", ty.Slice(elementType: ty.string)),
            //        ("Values", ty.Slice(elementType: ty.any)), // TODO: @Any
        ])

        static let named: BuiltinType = BuiltinType(name: "Named", structMembers: [
            ("Type", builtin.types.typeInfo.type),
        ])


        // - MARK: Functions

        static var sizeOf: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("SizeOf", type: ty.Function.make([ty.any], [builtin.untypedInteger.type])),
            generate: { function, exprs, gen in
                var type = exprs[0].type!
                if let meta = type as? ty.Metatype {
                    type = meta.instanceType
                }
                let irType = gen.canonicalize(type)
                // TODO: Ensure the integer returned matches the `untypedInteger` types width.
                return gen.b.buildSizeOf(irType)
            },
            onCallCheck: nil
        )


        static var typeOf: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("TypeOf", type: ty.Function.make([ty.any], [builtin.types.typeInfo.type])),
            generate: { function, exprs, gen in
                var type = baseType(exprs[0].type!) // FIXME: Don't unwrap named types
                if type is ty.Metatype {
                    type = type.lower()
                }


                return llvmTypeConstant(type, gen: &gen)
            },
            onCallCheck: { (checker, call) in
                guard call.args.count == 1 else {
                    checker.reportError("Expected 1 argument in call to 'typeInfo'", at: call.start)
                    return ty.invalid
                }

                _ = checker.check(expr: call.args[0])
                // FIXME: LOWER METATYPE

                return builtin.types.typeInfo.type
            }
        )
    }
}

//Compound = 0b000
//Boolean  = 0b001
//Integer  = 0b010
//Float    = 0b011
//Any      = 0b100

func typeTag(for type: Type) -> UInt8 {
    switch type {
    case is ty.Boolean:
        return 0b001
    case is ty.Integer:
        return 0b010
    case is ty.FloatingPoint:
        return 0b011
    case is ty.Anyy:
        return 0b100

    default:
        return 0b000
    }
}

func compoundTag(for type: Type) -> UInt8 {
    switch type {
    case is ty.Named:
        return 0b000
    case is ty.Function:
        return 0b001
    case is ty.Array:
        return 0b010
    case is ty.Vector:
        return 0b011
    case is ty.Struct:
        return 0b100
    case is ty.Union:
        return 0b101
    case is ty.Enum:
        return 0b110
    case is ty.Pointer:
        return 0b111
    default:
        fatalError()
    }
}

func llvmTypeConstant(_ type: Type, gen: inout IRGenerator) -> IRValue {
    let type = baseType(type)

    let tag = typeTag(for: type)

    var value: IRValue
    switch type {
    case is ty.Boolean:
        var val: UInt64 = 0
        val |= UInt64(type.width!) << 3
        val |= UInt64(tag)
        value = gen.i64.constant(val)

    case let type as ty.Integer:
        var val: UInt64 = 0
        val |= UInt64(type.width!) << 4
        val |= UInt64(type.isSigned ? 1 : 0) << 3
        val |= UInt64(tag)
        value = gen.i64.constant(val)

    case is ty.FloatingPoint:
        var val: UInt64 = 0
        val |= UInt64(type.width!) << 3
        val |= UInt64(tag)
        value = gen.i64.constant(val)

    default:
        // A compound constant is a pointer meaning it's bottom 3 bits must be unset to be valid making it's tag 0b000
        value = llvmCompoundConstant(type, gen: &gen)
    }

    let typeInfo = gen.canonicalize(builtin.types.typeInfo.type)
    value = gen.b.buildBitCast(value, type: typeInfo)
    return value
}

func llvmCompoundConstant(_ type: Type, gen: inout IRGenerator) -> Global {
    let type = baseType(type)

    let tag = compoundTag(for: type)

    var data: IRValue
    switch type {
    case let type as ty.Pointer:
        data = llvmTypeConstant(type.pointeeType, gen: &gen)

    case let type as ty.Slice:
        data = llvmTypeConstant(type.elementType, gen: &gen)

    case let type as ty.Array:
        let irType = gen.canonicalize(builtin.types.array.type) as! LLVM.StructType
        data = llvmTypeConstant(type.elementType, gen: &gen)
        data = irType.constant(values: [data, gen.i64.constant(type.length)])

    case let type as ty.Vector:
        let irType = gen.canonicalize(builtin.types.vector.type) as! LLVM.StructType
        data = llvmTypeConstant(type.elementType, gen: &gen)
        data = irType.constant(values: [data, gen.i64.constant(type.size)])

    case let type as ty.Struct:
        let irType = gen.canonicalize(builtin.types.vector.type) as! LLVM.StructType
        let flags = gen.i64.constant(0) // TODO
        let names = llvmConstantSlice(data: type.fields.orderedKeys, type: gen.canonicalize(ty.string), gen: &gen, canonicalize: { str, gen in
            return gen.emit(constantString: str)
        })
        let types = llvmConstantSlice(data: type.fields.orderedValues, type: gen.canonicalize(builtin.types.typeInfo.type), gen: &gen, canonicalize: { field, gen in
            return llvmTypeConstant(field.type, gen: &gen)
        })
        let offsets = llvmConstantSlice(data: type.fields.orderedValues, type: gen.canonicalize(ty.i64), gen: &gen, canonicalize: { field, gen in
            return gen.i64.constant(field.offset)
        })
        data = irType.constant(values: [flags, names, types, offsets])

    default:
        fatalError()
    }
    data = gen.b.buildBitCast(data, type: gen.canonicalize(builtin.types.compound.type))
    data = (gen.canonicalize(builtin.types.compound.type) as! LLVM.StructType).constant(values: [gen.i3.constant(tag), data])

    return gen.b.addGlobal("TypeInfo for \(type.description)", initializer: data)
}

// TODO: Useful to promote this into a more commonly used helper?
func llvmConstantSlice<T: Sequence>(data: T, type: IRType, gen: inout IRGenerator, canonicalize: (T.Element, inout IRGenerator) -> IRValue) -> IRValue {
    let values = data.map { canonicalize($0, &gen) }
    return LLVM.ArrayType.constant(values, type: type)
}

func patchTypesPackageCompoundPointer() {
    // patch up Type's compound pointer to be strongly typed
    let named = (builtin.types.typeInfo.type as! ty.Named)
    var typeInfo = named.base as! ty.Union
    let ident = typeInfo.cases["Compound"]!.ident
    typeInfo.cases["Compound"] = ty.Union.Case(ident: ident, type: ty.Pointer(pointeeType: builtin.types.compound.type))
    named.base = typeInfo
    builtin.types.typeInfo.type = named
}
