
import LLVM


// Key is Type.description.hashValue
var typeInfoTable: [String: IRValue] = [:]

extension builtin {

    /// - Note: This contains the entities used in the types builtin package
    enum types {

        // - MARK: Types

        static var typeInfo: BuiltinType = BuiltinType(name: "Type", flags: .inlineTag, tagWidth: 3, unionMembers: [

            // NOTE: Pointer members get patched to have the correct type after instantiation, this avoids a circular reference
            ("Simple",   simpleType, 0x00),
            ("Array",    ty.rawptr,  0x01), /* arrayType */
            ("Slice",    ty.rawptr,  0x02), /* sliceType */
            ("Pointer",  ty.rawptr,  0x03), /* pointerType */
            ("Function", ty.rawptr,  0x04), /* functionType */
            ("Struct",   ty.rawptr,  0x05), /* structType */
            ("Union",    ty.rawptr,  0x06), /* unionType */
            ("Enum",     ty.rawptr,  0x07), /* enumType */
        ])

        static let simple: BuiltinType = BuiltinType(name: "Simple", flags: .inlineTag, tagWidth: 8, unionMembers: [
            ("Integer", integerType, 0x00),
            ("Boolean", booleanType, 0x10),
            ("Float",   floatType,   0x20),
            ("Any",     anyType,     0x30),
            ("Void",    voidType,    0x40),
        ])

        static let boolean: BuiltinType = BuiltinType(name: "Boolean", flags: .packed, structMembers: [
            ("Tag", ty.u8),
            ("Width", ty.Integer(width: 16, isSigned: false)),
            ("pad", ty.u8),
            ("reserved", ty.u32),
        ])

        static let integer: BuiltinType = BuiltinType(name: "Integer", flags: .packed, structMembers: [
            ("Tag", ty.u8),
            ("Width", ty.u16),
            ("Signed", ty.Boolean(width: 8)),
            ("reserved", ty.u32),
        ])

        static let float: BuiltinType = BuiltinType(name: "Float", flags: .packed, structMembers: [
            ("Tag", ty.u8),
            ("Width", ty.u16),
            ("pad", ty.u8),
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
            generate: { function, returnAddress, args, gen in
                var type = baseType(args[0].type!) // FIXME: Don't unwrap named types
                if type is ty.Metatype {
                    type = type.lower()
                }
                if let existing = typeInfoTable[type.description] {
                    // FIXME: Thread safety
                    return existing
                }

                assert(gen.b.insertBlock != nil, "For now type info in the global scope is forbidden")

                let value = llvmTypeInfo(type, gen: &gen)

                typeInfoTable[type.description] = value
                assert(!returnAddress)
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
            case is ty.Integer:         return 0x00
            case is ty.Boolean:         return 0x10
            case is ty.Float:           return 0x20
            case is ty.Anyy:            return 0x30
            case is ty.Void:            return 0x40
            case is ty.Array:           return 0x01
            case is ty.Slice:           return 0x02
            case is ty.Pointer:         return 0x03
            case is ty.Function:        return 0x04
            case is ty.Struct:          return 0x05
            case is ty.Union:           return 0x06
            case is ty.Enum:            return 0x07
            default: fatalError()
            }
        }

        static func llvmTypeInfo(_ type: Type, gen: inout IRGenerator) -> IRValue {
            let canonical: (inout IRGenerator, Type) -> LLVM.StructType = {
                return $0.canonicalize($1) as! LLVM.StructType
            }

            let typeInfoUnionIr = canonical(&gen, typeInfoType)

            let type = baseType(type)
            
            let intptr = targetMachine.dataLayout.intPointerType(context: gen.module.context)

            let tag = tagForType(type)

            var value: IRValue
            switch type {
            case let type as ty.Struct:
                let structFieldTypeIR = canonical(&gen, structFieldType)
                var fieldsIr: [IRValue] = []
                for f in type.fields.orderedValues {
                    let ir = structFieldTypeIR.constant(values: [
                        gen.emit(constantString: f.name),
                        llvmTypeInfo(f.type, gen: &gen),
                        gen.i64.constant(f.offset),
                    ])

                    fieldsIr.append(ir)
                }

                let structTypeIr = canonical(&gen, structType)
                var value: IRValue = structTypeIr.constant(values: [
                    llvmSlice(values: fieldsIr, type: structFieldTypeIR, gen: &gen),
                    gen.i64.constant(0xC0FEBABE), // flags
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case let type as ty.Function:
                let params = type.params.map({ llvmTypeInfo($0, gen: &gen) })
                let results = type.returnType.types.map({ llvmTypeInfo($0, gen: &gen) })

                let functionTypeIr = canonical(&gen, functionType)
                var value: IRValue = functionTypeIr.constant(values: [
                    llvmSlice(values: params, type: typeInfoUnionIr, gen: &gen),
                    llvmSlice(values: results, type: typeInfoUnionIr, gen: &gen),
                    gen.i64.constant(0xC0FEBABE), // flags
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case let type as ty.Array:
                let arrayTypeIr = canonical(&gen, arrayType)
                var value: IRValue = arrayTypeIr.constant(values: [
                    gen.i64.constant(type.length),
                    gen.i64.constant(0xC0FEBABE),
                    llvmTypeInfo(type.elementType, gen: &gen)
                ])
                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case is ty.Vector:
                fatalError()
            case let type as ty.Union:
                var casesIr: [IRValue] = []

                let caseTypeIr = canonical(&gen, unionCaseType)
                for c in type.cases.orderedValues {
                    let ir = caseTypeIr.constant(values: [
                        gen.emit(constantString: c.ident.name),
                        llvmTypeInfo(c.type, gen: &gen),
                        gen.i64.constant(c.tag),
                    ])

                    casesIr.append(ir)
                }

                var value: IRValue = canonical(&gen, unionType).constant(values: [
                    llvmSlice(values: casesIr, type: caseTypeIr, gen: &gen),
                    gen.i64.constant(0xC0FEBABE),
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case let type as ty.Enum:
                var casesIr: [IRValue] = []

                let caseTypeIr = canonical(&gen, enumCaseType)
                for (index, c) in type.cases.orderedValues.enumerated() {

                    let ir = caseTypeIr.constant(values: [
                        gen.emit(constantString: c.ident.name),
                        gen.i64.constant(index),
                    ])
                    casesIr.append(ir)
                }

                var value: IRValue = canonical(&gen, enumType).constant(values: [
                    llvmSlice(values: casesIr, type: canonical(&gen, enumCaseType), gen: &gen),
                    gen.i64.constant(0xC0FEBABE),
                ])

                var global = gen.b.addGlobal("TypeInfo for \(type)", initializer: value)
                global.isGlobalConstant = true
                value = const.ptrToInt(global, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case let type as ty.Slice:
                value = llvmTypeInfo(type.elementType, gen: &gen)
                value = const.ptrToInt(value, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case let type as ty.Pointer:
                value = llvmTypeInfo(type.pointeeType, gen: &gen)
                value = const.ptrToInt(value, to: intptr)
                value = const.or(value, tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case is ty.Anyy, is ty.Void:
                value = intptr.constant(tag)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case is ty.Boolean, is ty.Float:
                assert(type.width! < numericCast(UInt16.max))
                var v: UInt64 = 0
                v |= UInt64(type.width!) << 8
                v |= UInt64(tag)
                value = intptr.constant(v)
                value = typeInfoUnionIr.constant(values: [value])
                return value

            case let type as ty.Integer:
                assert(type.width! < numericCast(UInt16.max))
                var v: UInt64 = 0
                v |= UInt64(type.width!) << 8
                v |= UInt64(type.isSigned ? 1 : 0) << 24
                v |= UInt64(tag)
                value = intptr.constant(v)
                value = typeInfoUnionIr.constant(values: [value])
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

            return sliceType.constant(values: [const.bitCast(global, to: elPointer), gen.i64.constant(values.count), gen.i64.constant(0xDEADC0DE)])
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
