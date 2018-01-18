
import LLVM
import cllvm

extension builtin {

    /// - Note: This contains the entities used in the types builtin package
    enum types {

        // - MARK: Types

        static var typeInfo: BuiltinType = BuiltinType(name: "Type", flags: .inlineTag, unionMembers: [
            // NOTE: Pointer members get patched to have the correct type after instantiation, this avoids a circular reference
            ("Struct",   ty.rawptr /*ty.Pointer(structType)*/),    // 0x0
            ("Function", ty.rawptr /*ty.Pointer(functionType)*/),  // 0x1
            ("Array",    ty.rawptr /*ty.Pointer(arrayType)*/),     // 0x2
            ("Vector",   ty.rawptr /*ty.Pointer(vectorType)*/),    // 0x3
            ("Union",    ty.rawptr /*ty.Pointer(unionType)*/),     // 0x4
            ("Enum",     ty.rawptr /*ty.Pointer(enumType)*/),      // 0x5
            ("Slice",    ty.rawptr /*ty.Pointer(sliceType)*/),     // 0x6
            ("Pointer",  ty.rawptr /*ty.Pointer(pointerType)*/),   // 0x7
            ("Any",      anyType),                                 // 0x8
            ("Float",    floatType),                               // 0x9
            ("Boolean",  booleanType),                             // 0xA
            ("Integer",  integerType),                             // 0xB
        ])

        static let boolean: BuiltinType = BuiltinType(name: "Boolean", flags: .packed, structMembers: [
            ("reserved", ty.Integer(width: 32, isSigned: false)),
            ("Width", ty.Integer(width: 32, isSigned: false)),
        ])

        static let integer: BuiltinType = BuiltinType(name: "Integer", flags: .packed, structMembers: [
            ("reserved", ty.Integer(width: 16, isSigned: false)),
            ("Signed", ty.Boolean(width: 16)),
            ("Width", ty.Integer(width: 32, isSigned: false)),
        ])

        static let float: BuiltinType = BuiltinType(name: "Float", flags: .packed, structMembers: [
            ("reserved", ty.Integer(width: 32, isSigned: false)),
            ("Width", ty.Integer(width: 32, isSigned: false)),
        ])

        static let any: BuiltinType = BuiltinType(name: "Any", structMembers: [
            ("reserved", ty.Integer(width: 64, isSigned: false)),
        ])

        static let pointer: BuiltinType = BuiltinType(name: "Pointer", structMembers: [
            ("PointeeType", typeInfoType),
        ])

        static let slice: BuiltinType = BuiltinType(name: "Slice", structMembers: [
            ("ElementType", typeInfoType),
        ])

        static let function: BuiltinType = BuiltinType(name: "Function", structMembers: [
            ("Params", ty.Slice(elementType: paramType)),
            ("Results", ty.Slice(elementType: paramType)),
        ])

        static let array: BuiltinType = BuiltinType(name: "Array", structMembers: [
            ("ElementType", typeInfoType),
            ("Size", ty.Integer(width: 64, isSigned: false)),
        ])

        static let vector: BuiltinType = BuiltinType(name: "Vector", structMembers: [
            ("ElementType", typeInfoType),
            ("Size", ty.Integer(width: 64, isSigned: false)),
        ])

        static let `struct`: BuiltinType = BuiltinType(name: "Struct", structMembers: [
            ("Flags", ty.Integer(width: 64, isSigned: false)),
            ("Names", ty.Slice(elementType: ty.string)),
            ("Types", ty.Slice(elementType: typeInfoType)),
            ("Offsets", ty.Slice(elementType: ty.u64)),
        ])

        static let union: BuiltinType = BuiltinType(name: "Union", structMembers: [
            ("Flags", ty.Integer(width: 64, isSigned: false)),
            ("Types", ty.Slice(elementType: typeInfoType)),
        ])

        static let `enum`: BuiltinType = BuiltinType(name: "Enum", structMembers: [
            ("BaseType", ty.Pointer(typeInfoType)),
            ("Names", ty.Slice(elementType: ty.string)),
            //        ("Values", ty.Slice(elementType: ty.any)), // TODO: @Any
        ])

        static let named: BuiltinType = BuiltinType(name: "Named", structMembers: [
            ("Name", ty.string),
            ("Type", typeInfoType),
        ])

        static let param: BuiltinType = BuiltinType(name: "Param", structMembers: [
            ("Name", ty.string),
            ("Type", typeInfoType),
        ])


        // - MARK: Functions

        // sourcery: type = "ty.Function"
        static var sizeOf: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("SizeOf", type: ty.Function.make([ty.any], [builtin.untypedInteger.type])),
            generate: { function, returnAddress, exprs, gen in
                assert(!returnAddress)
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

        // sourcery: type = "ty.Function"
        static var typeOf: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("TypeOf", type: ty.Function.make([ty.any], [typeInfoType])),
            generate: { function, returnAddress, exprs, gen in
                var type = baseType(exprs[0].type!) // FIXME: Don't unwrap named types
                if type is ty.Metatype {
                    type = type.lower()
                }

                let value = llvmTypeConstant(type, returnAddress: returnAddress, gen: &gen)
                assert(!returnAddress || value.type is LLVM.PointerType)
                return value
            },
            onCallCheck: { (checker, call) in
                guard call.args.count == 1 else {
                    checker.reportError("Expected 1 argument in call to 'TypeOf'", at: call.start)
                    return ty.invalid
                }

                _ = checker.check(expr: call.args[0])

                return typeInfoType
            }
        )

        static func tagForType(_ type: Type) -> Int {
            switch type {
            case is ty.Struct:        return 0x0
            case is ty.Function:      return 0x1
            case is ty.Array:         return 0x2
            case is ty.Vector:        return 0x3
            case is ty.Union:         return 0x4
            case is ty.Enum:          return 0x5
            case is ty.Slice:         return 0x6
            case is ty.Pointer:       return 0x7
            case is ty.Anyy:          return 0x8
            case is ty.FloatingPoint: return 0x9
            case is ty.Boolean:       return 0xA
            case is ty.Integer:       return 0xB
            default: fatalError()
            }
        }

        static func llvmTypeConstant(_ type: Type, returnAddress: Bool = false, gen: inout IRGenerator) -> IRValue {
            let canonical: (inout IRGenerator, Type) -> LLVM.StructType = {
                return $0.canonicalize($1) as! LLVM.StructType
            }

            let type = baseType(type)

            let intptr = targetMachine.dataLayout.intPointerType(context: gen.module.context)

            var value: IRValue
            switch type {
            case is ty.Struct:
                fatalError()
            case is ty.Function:
                fatalError()
            case let type as ty.Array:
                let elementType = llvmTypeConstant(type.elementType, gen: &gen)
                let size = LLVM.IntType(width: 64, in: gen.module.context).constant(type.length)
                value = canonical(&gen, arrayType).constant(values: [
                    elementType,
                    size,
                ])
            case is ty.Vector:
                fatalError()
            case is ty.Union:
                fatalError()
            case is ty.Enum:
                fatalError()
            case let type as ty.Slice:
                value = llvmTypeConstant(type.elementType, returnAddress: true, gen: &gen)
                assert(value.type is LLVM.PointerType)
            case let type as ty.Pointer:
                value = llvmTypeConstant(type.pointeeType, returnAddress: true, gen: &gen)
                assert(value.type is LLVM.PointerType)
            case is ty.Anyy:
                value = intptr.constant(0)
            case is ty.Boolean, is ty.FloatingPoint:
                // reserved: 32, width: 32
                value = intptr.constant(UInt64(0) | UInt64(type.width!) << 32)
            case let type as ty.Integer:
                // reserved: 16, signed: 16, width: 32
                var v: UInt64 = 0
                v = v | UInt64(type.isSigned ? 1 : 0) << 16
                v = v | UInt64(type.width!) << 32
                value = intptr.constant(v)
            default:
                fatalError()
            }

            let tag = tagForType(type)

            switch value.type {
            case is LLVM.PointerType:
                value = gen.b.buildPtrToInt(value, type: intptr)
            default:
                value = gen.b.buildBitCast(value, type: intptr)
            }

            value = gen.b.buildOr(value, intptr.constant(tag))

            var global = gen.b.addGlobal("TypeInfo for \(type.description)", initializer: canonical(&gen, typeInfoType).undef())
            // NOTE: Because we use 4 bits for the tag on the pointer the pointer must
            //  be aligned to a 16 byte boundary to ensure that the lower 4 bits are available
            global.alignment = 16
            global.isGlobalConstant = false
            let dummyGlobalPointer = gen.b.buildBitCast(global, type: LLVM.PointerType(pointee: intptr))
            gen.b.buildStore(value, to: dummyGlobalPointer, alignment: 16)

            if !returnAddress {
                return gen.b.buildLoad(global, alignment: 16)
            }

            return global
        }

        static func patchTypes() {

            let named = (builtin.types.typeInfo.type as! ty.Named)
            var type = named.base as! ty.Union
            type.cases["Struct"]!.type = ty.Pointer(structType)
            type.cases["Function"]!.type = ty.Pointer(functionType)
            type.cases["Array"]!.type = ty.Pointer(arrayType)
            type.cases["Vector"]!.type = ty.Pointer(vectorType)
            type.cases["Union"]!.type = ty.Pointer(unionType)
            type.cases["Enum"]!.type = ty.Pointer(enumType)
            type.cases["Slice"]!.type = ty.Pointer(sliceType)
            type.cases["Pointer"]!.type = ty.Pointer(pointerType)
            named.base = type
            builtin.types.typeInfo.type = named
        }
    }
}

// TODO: Useful to promote this into a more commonly used helper?
func llvmConstantSlice<T: Sequence>(data: T, type: IRType, gen: inout IRGenerator, canonicalize: (T.Element, inout IRGenerator) -> IRValue) -> IRValue {
    let values = data.map { canonicalize($0, &gen) }
    return LLVM.ArrayType.constant(values, type: type)
}
