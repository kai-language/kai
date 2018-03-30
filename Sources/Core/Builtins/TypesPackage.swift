
import LLVM

// Key is Type.description.hashValue
var typeInfoTable: [String: IRValue] = [:]

private let flagUntypedValue = UInt64(0x1 << 24)
private let flagSignedValue  = UInt64(0x2 << 24)
private let flagVectorValue  = UInt64(0x1)

extension builtin {

    /// - Note: This contains the entities used in the types builtin package
    enum types {

        // - MARK: Types

        static var typeInfo: BuiltinType = BuiltinType(name: "Type", flags: .inlineTag, tagWidth: 3, unionMembers: [

            // NOTE: Pointer members get patched to have the correct type after instantiation, this avoids a circular reference
            ("Simple",   simpleType, 0x00),
            ("Array",    ty.rawptr,  tagForType(ty.Array.self)),    /* arrayType */
            ("Slice",    ty.rawptr,  tagForType(ty.Slice.self)),    /* sliceType */
            ("Pointer",  ty.rawptr,  tagForType(ty.Pointer.self)),  /* pointerType */
            ("Function", ty.rawptr,  tagForType(ty.Function.self)), /* functionType */
            ("Struct",   ty.rawptr,  tagForType(ty.Struct.self)),   /* structType */
            ("Union",    ty.rawptr,  tagForType(ty.Union.self)),    /* unionType */
            ("Enum",     ty.rawptr,  tagForType(ty.Enum.self)),     /* enumType */
        ])

        static let simple: BuiltinType = BuiltinType(name: "Simple", flags: .inlineTag, tagWidth: 8, unionMembers: [
            ("Integer", integerType, tagForType(ty.Integer.self)),
            ("Boolean", booleanType, tagForType(ty.Boolean.self)),
            ("Float",   floatType,   tagForType(ty.Float.self)),
            ("Any",     anyType,     tagForType(ty.Anyy.self)),
            ("Void",    voidType,    tagForType(ty.Void.self)),
        ])

        static let boolean: BuiltinType = BuiltinType(name: "Boolean", flags: .packed, structMembers: [
            ("Tag", ty.u8),
            ("Width", ty.Integer(width: 16, isSigned: false)),
            ("Flags", ty.u8),
            ("reserved", ty.u32),
        ])

        static let integer: BuiltinType = BuiltinType(name: "Integer", flags: .packed, structMembers: [
            ("Tag", ty.u8),
            ("Width", ty.u16),
            ("Flags", ty.u8),
            ("reserved", ty.u32),
        ])

        static let float: BuiltinType = BuiltinType(name: "Float", flags: .packed, structMembers: [
            ("Tag", ty.u8),
            ("Width", ty.u16),
            ("Flags", ty.u8),
            ("reserved", ty.u32),
        ])

        static let any: BuiltinType = BuiltinType(name: "Any", structMembers: [
            ("reserved", ty.u64),
        ])

        static let void: BuiltinType = BuiltinType(name: "Void", structMembers: [
            ("Reserved", ty.u64),
        ])

        static let array: BuiltinType = BuiltinType(name: "Array", structMembers: [
            ("Length", ty.u64),
            ("Flags", ty.u64),
            ("ElementType", typeInfoType),
        ])

        static let pointer: BuiltinType = BuiltinType(name: "Pointer", structMembers: [
            ("PointeeType", typeInfoType),
        ])

        static let slice: BuiltinType = BuiltinType(name: "Slice", structMembers: [
            ("ElementType", typeInfoType),
            ("Flags", ty.u64),
        ])

        static let function: BuiltinType = BuiltinType(name: "Function", structMembers: [
            ("Params", ty.Slice(typeInfoType)),
            ("Results", ty.Slice(typeInfoType)),
            ("Flags", ty.u64),
        ])

        static let `struct`: BuiltinType = BuiltinType(name: "Struct", structMembers: [
            ("Fields", ty.Slice(structFieldType)),
            ("Flags", ty.u64),
        ])

        static let structField: BuiltinType = BuiltinType(name: "StructField", structMembers: [
            ("Name", ty.string),
            ("Type", typeInfoType),
            ("Offset", ty.u64),
        ])

        static let union: BuiltinType = BuiltinType(name: "Union", structMembers: [
            ("Cases", ty.Slice(unionCaseType)),
            ("Flags", ty.u64),
        ])

        static let unionCase: BuiltinType = BuiltinType(name: "UnionCase", structMembers: [
            ("Name", ty.string),
            ("Type", typeInfoType),
            ("Tag", ty.u64),
        ])

        static let `enum`: BuiltinType = BuiltinType(name: "Enum", structMembers: [
            ("Cases", ty.Slice(enumCaseType)),
            ("BackingType", typeInfoType),
            ("Flags", ty.u64),
        ])

        static let enumCase: BuiltinType = BuiltinType(name: "EnumCase", structMembers: [
            ("Name", ty.string),
            ("Tag", ty.u64),
            // ("Value", ty.any),
        ])

        static let named: BuiltinType = BuiltinType(name: "Named", structMembers: [
            ("Name", ty.string),
            ("Type", typeInfoType),
        ])


        // - MARK: Constants

        static var flagUntyped: BuiltinEntity = BuiltinEntity(name: "FlagUntyped", flags: .constant, type: ty.u64, gen: { $0.word.constant(flagUntypedValue) })
        static var flagSigned: BuiltinEntity = BuiltinEntity(name: "FlagSigned", flags:   .constant, type: ty.u64, gen: { $0.word.constant(flagSignedValue) })
        static var flagVector: BuiltinEntity = BuiltinEntity(name: "FlagVector", flags:   .constant, type: ty.u64, gen: { $0.word.constant(flagVectorValue) })
        static var flagString: BuiltinEntity = BuiltinEntity(name: "FlagString", flags:   .constant, type: ty.u64, gen: { $0.word.constant(ty.Slice.Flags.string.rawValue) })

        // - MARK: Functions

        // sourcery: type = "ty.Function"
        static var sizeOf: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("SizeOf", type: ty.Function.make([ty.any], [builtin.untypedInteger.type])),
            generate: { function, returnAddress, call, gen in
                assert(!returnAddress)
                var type = call.args[0].type
                var width = type.width
                if let meta = type as? ty.Metatype {
                    type = meta.instanceType
                    width = type.width
                }
                let irType = gen.canonicalize(type)

                assert(width == targetMachine.dataLayout.sizeOfTypeInBits(irType))
                // TODO: Ensure the integer returned matches the `untypedInteger` types width.
                return gen.b.buildSizeOf(irType)
            },
            onCallCheck: { (checker, call) in
                guard call.args.count == 1 else {
                    checker.reportError("Expected 1 argument in call to 'TypeOf'", at: call.start)
                    return Operand.invalid
                }

                let argOp = checker.check(expr: call.args[0])
                var type = argOp.type!
                if type is ty.Metatype {
                    type = checker.lowerFromMetatype(call.args[0].type, atNode: call.args[0])
                }

                let width = UInt64(type.width!.bytes())
                return Operand(
                    mode: .computed,
                    expr: call,
                    type: ty.untypedInteger,
                    constant: width,
                    dependencies: argOp.dependencies
                )
            }
        )

        // sourcery: type = "ty.Function"
        static var typeOf: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("TypeOf", type: ty.Function.make([ty.any], [typeInfoType])),
            generate: { function, returnAddress, call, gen in
                var type = baseType(call.args[0].type) // FIXME: Don't unwrap named types
                if type is ty.Metatype {
                    type = type.lower()
                }

                assert(gen.b.insertBlock != nil, "For now type info in the global scope is forbidden")
                let value = llvmTypeInfo(type, gen: &gen)
                assert(!returnAddress)
                return value
            },
            onCallCheck: { (checker, call) in
                guard call.args.count == 1 else {
                    checker.reportError("Expected 1 argument in call to 'TypeOf'", at: call.start)
                    return Operand.invalid
                }

                _ = checker.check(expr: call.args[0])

                return Operand(mode: .type, expr: nil, type: typeInfoType, constant: nil, dependencies: [])
            }
        )

        static func tagForType(_ type: Type.Type) -> Int {
            switch type {
            case is ty.UntypedInteger.Type:  return 0x10 // Untyped is a flag on Integer
            case is ty.Integer.Type:         return 0x10
            case is ty.Boolean.Type:         return 0x20
            case is ty.Float.Type:           return 0x30
            case is ty.UntypedFloat.Type:    return 0x30 // Untyped is a flag on Float
            case is ty.Anyy.Type:            return 0x40
            case is ty.Void.Type:            return 0x50
            case is ty.Array.Type:           return 0x01
            case is ty.Vector.Type:          return 0x01 // Vectors have a flag set on the Array structure
            case is ty.Slice.Type:           return 0x02
            case is ty.Pointer.Type:         return 0x03
            case is ty.Function.Type:        return 0x04
            case is ty.Struct.Type:          return 0x05
            case is ty.Union.Type:           return 0x06
            case is ty.Enum.Type:            return 0x07
            default: fatalError()
            }
        }

        static func llvmTypeInfo(_ type: Type, gen: inout IRGenerator) -> IRValue {
            if let existing = typeInfoTable[type.description] { // FIXME: Thread safety
                return existing
            }

            let canonical: (inout IRGenerator, Type) -> LLVM.StructType = {
                return $0.canonicalize($1) as! LLVM.StructType
            }

            let typeInfoUnionIr = canonical(&gen, typeInfoType)

            let type = baseType(type)

            let intptr = targetMachine.dataLayout.intPointerType(context: gen.module.context)

            let tag = tagForType(Swift.type(of: type))

            var value: IRValue
            switch type {
            case let type as ty.Struct:
                let structFieldTypeIR = canonical(&gen, structFieldType)
                var fieldsIr: [IRValue] = []
                for f in type.fields.orderedValues {
                    let ir = structFieldTypeIR.constant(values: [
                        gen.emit(constantString: f.name),
                        llvmTypeInfo(f.type, gen: &gen),
                        gen.word.constant(f.offset),
                    ])

                    fieldsIr.append(ir)
                }

                let structTypeIr = canonical(&gen, structType)
                var value: IRValue = structTypeIr.constant(values: [
                    llvmSlice(values: fieldsIr, type: structFieldTypeIR, gen: &gen),
                    gen.word.constant(0x0), // flags
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case let type as ty.Function:
                let params = type.params.map({ llvmTypeInfo($0, gen: &gen) })
                let results = type.returnType.types.map({ llvmTypeInfo($0, gen: &gen) })

                let functionTypeIr = canonical(&gen, functionType)
                var value: IRValue = functionTypeIr.constant(values: [
                    llvmSlice(values: params, type: typeInfoUnionIr, gen: &gen),
                    llvmSlice(values: results, type: typeInfoUnionIr, gen: &gen),
                    gen.word.constant(0x0), // flags
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case is ty.Array, is ty.Vector:
                let len = (type as? ty.Array)?.length ?? (type as! ty.Vector).size
                let elType = (type as? ty.Array)?.elementType ?? (type as! ty.Vector).elementType

                let arrayTypeIr = canonical(&gen, arrayType)
                var value: IRValue = arrayTypeIr.constant(values: [
                    gen.word.constant(len),
                    gen.word.constant(isVector(type) ? flagVectorValue : 0),
                    llvmTypeInfo(elType, gen: &gen)
                ])
                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case let type as ty.Union:
                var casesIr: [IRValue] = []

                let caseTypeIr = canonical(&gen, unionCaseType)
                for c in type.cases.orderedValues {
                    let ir = caseTypeIr.constant(values: [
                        gen.emit(constantString: c.ident.name),
                        llvmTypeInfo(c.type, gen: &gen),
                        gen.word.constant(c.tag),
                    ])

                    casesIr.append(ir)
                }

                var value: IRValue = canonical(&gen, unionType).constant(values: [
                    llvmSlice(values: casesIr, type: caseTypeIr, gen: &gen),
                    gen.word.constant(0x0),
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case let type as ty.Enum:
                var casesIr: [IRValue] = []

                let caseTypeIr = canonical(&gen, enumCaseType)
                for (index, c) in type.cases.orderedValues.enumerated() {

                    let ir = caseTypeIr.constant(values: [
                        gen.emit(constantString: c.ident.name),
                        gen.word.constant(index),
                    ])
                    casesIr.append(ir)
                }

                var value: IRValue = canonical(&gen, enumType).constant(values: [
                    llvmSlice(values: casesIr, type: canonical(&gen, enumCaseType), gen: &gen),
                    llvmTypeInfo(type.backingType, gen: &gen),
                    gen.word.constant(0x0),
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case let type as ty.Slice:
                let sliceTypeIr = canonical(&gen, sliceType)
                var value: IRValue = sliceTypeIr.constant(values: [
                    llvmTypeInfo(type.elementType, gen: &gen),
                    gen.word.constant(type.flags.rawValue),
                ])
                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case let type as ty.Pointer:
                let pointeeType = llvmTypeInfo(type.pointeeType, gen: &gen)
                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: pointeeType)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case is ty.Anyy, is ty.Void:
                value = intptr.constant(tag)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case is ty.Boolean, is ty.Float, is ty.UntypedFloat:
                assert(type.width! < numericCast(UInt16.max))
                var v: UInt64 = 0
                v |= isUntypedFloat(type) ? flagUntypedValue : 0
                v |= UInt64(type.width!) << 8
                v |= UInt64(tag)
                value = intptr.constant(v)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            case is ty.Integer, is ty.UntypedInteger:
                assert(type.width! < numericCast(UInt16.max))
                var v: UInt64 = 0
                v |= UInt64(type.width!) << 8
                v |= isSigned(type) ? flagUntypedValue : 0
                v |= isUntypedInteger(type) ? flagSignedValue : 0
                v |= UInt64(tag)
                value = intptr.constant(v)
                value = typeInfoUnionIr.constant(values: [value])
                typeInfoTable[type.description] = value
                return value

            default:
                fatalError()
            }
        }

        static func llvmSlice(values: [IRValue], type: IRType, gen: inout IRGenerator) -> IRValue {
            let elPointer = LLVM.PointerType(pointee: type)
            let sliceType = LLVM.StructType(elementTypes: [elPointer, gen.word, gen.word], in: gen.module.context)
            guard !values.isEmpty else {
                return sliceType.null() // all zero's
            }

            var global = gen.b.addGlobal("", initializer: LLVM.ArrayType.constant(values, type: type))
            global.isGlobalConstant = true

            return sliceType.constant(values: [const.bitCast(global, to: elPointer), gen.word.constant(values.count), gen.word.constant(0xDEADC0DE)])
        }

        static func patchTypes() {

            let named = (builtin.types.typeInfo.type as! ty.Named)
            var type = named.base as! ty.Union
            type.cases["Struct"]!.type = ty.Pointer(structType)
            type.cases["Function"]!.type = ty.Pointer(functionType)
            type.cases["Array"]!.type = ty.Pointer(arrayType)
            type.cases["Union"]!.type = ty.Pointer(unionType)
            type.cases["Enum"]!.type = ty.Pointer(enumType)
            type.cases["Slice"]!.type = ty.Pointer(sliceType)
            type.cases["Pointer"]!.type = ty.Pointer(pointerType)
            named.base = type
            builtin.types.typeInfo.type = named
        }
    }
}
