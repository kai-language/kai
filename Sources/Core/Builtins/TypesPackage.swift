
import LLVM
import cllvm


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

                let value = llvmTypeInfo(type, returnAddress: true, gen: &gen)

                typeInfoTable[type.description] = value
                assert(!returnAddress || value.type is LLVM.PointerType)

                if !returnAddress {
                    return gen.buildLoad(value, alignment: 8)
                }
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
            case is ty.Float:   return 0x20
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

        static func llvmTypeInfo(_ type: Type, returnAddress: Bool = false, gen: inout IRGenerator) -> IRValue {
            let canonical: (inout IRGenerator, Type) -> LLVM.StructType = {
                return $0.canonicalize($1) as! LLVM.StructType
            }

            let type = baseType(type)

            let intptr = targetMachine.dataLayout.intPointerType(context: gen.module.context)

            var value: IRValue
            switch type {
            case let type as ty.Struct:
                var fieldsIr: [IRValue] = []
                for f in type.fields.orderedValues {
                    let name = gen.emit(constantString: f.name)
                    let type = llvmTypeInfo(f.type, gen: &gen)
                    let offs = gen.i64.constant(f.offset)

                    var ir = canonical(&gen, structFieldType).undef()
                    ir = gen.b.buildInsertValue(aggregate: ir, element: name, index: 0)
                    ir = gen.b.buildInsertValue(aggregate: ir, element: type, index: 1)
                    ir = gen.b.buildInsertValue(aggregate: ir, element: offs, index: 2)
                    fieldsIr.append(ir)
                }

                let fields = llvmSlice(values: fieldsIr, type: canonical(&gen, structFieldType), gen: &gen)
                let flags = gen.i64.constant(0xC0FEBABE) // TODO

                value = canonical(&gen, structType).undef()
                value = gen.b.buildInsertValue(aggregate: value, element: fields, index: 0)
                value = gen.b.buildInsertValue(aggregate: value, element: flags, index: 1)

                var global = gen.b.addGlobal("StructTypeInfo for \(type)", initializer: value.type.undef())
                global.isGlobalConstant = false
                gen.b.buildStore(value, to: global)
                value = global

            case let type as ty.Function:
                let params = type.params.map({ llvmTypeInfo($0, gen: &gen) })
                let results = type.returnType.types.map({ llvmTypeInfo($0, gen: &gen) })
                value = canonical(&gen, functionType).undef()

                let paramSlice = llvmSlice(values: params, type: canonical(&gen, typeInfoType), gen: &gen)
                let resultSlice = llvmSlice(values: results, type: canonical(&gen, typeInfoType), gen: &gen)
                let flags = gen.i64.constant(0xC0FEBABE) // TODO

                value = gen.b.buildInsertValue(aggregate: value, element: paramSlice, index: 0)
                value = gen.b.buildInsertValue(aggregate: value, element: resultSlice, index: 1)
                value = gen.b.buildInsertValue(aggregate: value, element: flags, index: 2)

                var global = gen.b.addGlobal("FunctionTypeInfo for \(type)", initializer: value.type.undef())
                global.isGlobalConstant = false
                gen.b.buildStore(value, to: global)
                value = global

            case let type as ty.Array:
                let length = gen.i64.constant(type.length)
                let flags  = gen.i64.constant(0xC0FEBABE) // TODO
                let elementType = llvmTypeInfo(type.elementType, gen: &gen)
                value = canonical(&gen, arrayType).undef()
                value = gen.b.buildInsertValue(aggregate: value, element: length, index: 0)
                value = gen.b.buildInsertValue(aggregate: value, element: flags, index: 1)
                value = gen.b.buildInsertValue(aggregate: value, element: elementType, index: 2)
                var global = gen.b.addGlobal("ArrayTypeInfo for \(type)", initializer: value.type.undef())
                global.isGlobalConstant = false
                gen.b.buildStore(value, to: global)
                value = global

            case is ty.Vector:
                fatalError()
            case let type as ty.Union:
                var casesIr: [IRValue] = []
                for c in type.cases.orderedValues {
                    let name = gen.emit(constantString: c.ident.name)
                    let type = llvmTypeInfo(c.type, gen: &gen)
                    let tag  = gen.i64.constant(c.tag)

                    var ir = canonical(&gen, unionCaseType).undef()
                    ir = gen.b.buildInsertValue(aggregate: ir, element: name, index: 0)
                    ir = gen.b.buildInsertValue(aggregate: ir, element: type, index: 1)
                    ir = gen.b.buildInsertValue(aggregate: ir, element: tag,  index: 2)
                    casesIr.append(ir)
                }

                let cases = llvmSlice(values: casesIr, type: canonical(&gen, unionCaseType), gen: &gen)
                let flags = gen.i64.constant(0xC0FEBABE) // TODO

                value = canonical(&gen, unionType).undef()
                value = gen.b.buildInsertValue(aggregate: value, element: cases, index: 0)
                value = gen.b.buildInsertValue(aggregate: value, element: flags, index: 1)

                var global = gen.b.addGlobal("UnionTypeInfo for \(type)", initializer: value.type.undef())
                global.isGlobalConstant = false
                gen.b.buildStore(value, to: global)
                value = global

            case let type as ty.Enum:
                var casesIr: [IRValue] = []
                for (index, c) in type.cases.orderedValues.enumerated() {
                    let name = gen.emit(constantString: c.ident.name)
                    let tag  = gen.i64.constant(index)

                    var ir = canonical(&gen, enumCaseType).undef()
                    ir = gen.b.buildInsertValue(aggregate: ir, element: name, index: 0)
                    ir = gen.b.buildInsertValue(aggregate: ir, element: tag, index: 1)
                    casesIr.append(ir)
                }

                let cases = llvmSlice(values: casesIr, type: canonical(&gen, enumCaseType), gen: &gen)
                let flags = gen.i64.constant(0xC0FEBABE)

                value = canonical(&gen, enumType).undef()
                value = gen.b.buildInsertValue(aggregate: value, element: cases, index: 0)
                value = gen.b.buildInsertValue(aggregate: value, element: flags, index: 1)

                var global = gen.b.addGlobal("EnumTypeInfo for \(type)", initializer: value.type.undef())
                global.isGlobalConstant = false
                gen.b.buildStore(value, to: global)
                value = global

            case let type as ty.Slice:
                value = llvmTypeInfo(type.elementType, returnAddress: true, gen: &gen)
                assert(value.type is LLVM.PointerType)

            case let type as ty.Pointer:
                value = llvmTypeInfo(type.pointeeType, returnAddress: true, gen: &gen)
                assert(value.type is LLVM.PointerType)

            case is ty.Anyy, is ty.Void:
                value = intptr.constant(0)

            case is ty.Boolean, is ty.Float:
                assert(type.width! < numericCast(UInt16.max))
                value = intptr.constant(0 | UInt64(type.width!) << 8)

            case let type as ty.Integer:
                assert(type.width! < numericCast(UInt16.max))
                value = intptr.constant(0 | UInt64(type.width!) << 8 | UInt64(type.isSigned ? 1 : 0) << 24)

            default:
                fatalError()
            }

            let tag = tagForType(type)

            switch value.type {
            case is LLVM.PointerType:
                value = gen.b.buildPtrToInt(value, type: intptr)
            case is LLVM.StructType:
                fatalError("LLVM doesn't allow any form of conversion for aggregate types without going through memory")
            default:
                value = gen.b.buildBitCast(value, type: intptr)
            }

            value = gen.b.buildOr(value, intptr.constant(tag))

            let irType = canonical(&gen, typeInfoType)

            var global = gen.b.addGlobal("TypeInfo for \(type.description)", initializer: irType.undef())
            global.alignment = 8
            global.isGlobalConstant = false
            let dummyGlobalPointer = gen.b.buildBitCast(global, type: LLVM.PointerType(pointee: intptr))
            gen.b.buildStore(value, to: dummyGlobalPointer, alignment: 8)

            if !returnAddress {
                return gen.buildLoad(global, alignment: 8)
            }

            return global
        }

        static func llvmSlice(values: [IRValue], type: IRType, gen: inout IRGenerator) -> IRValue {
            let indices: [IRValue]
            var valuesAddress: IRValue
            if !values.isEmpty {
                var array = LLVM.ArrayType(elementType: type, count: values.count).undef()
                for (index, value) in values.enumerated() {
                    array = gen.b.buildInsertValue(aggregate: array, element: value, index: index)
                }
                indices = [gen.i64.zero(), gen.i64.zero()]
                var global = gen.b.addGlobal("", initializer: array.type.undef())
                global.isGlobalConstant = false
                gen.b.buildStore(array, to: global)
                valuesAddress = global
            } else {
                indices = [gen.i64.zero()]
                valuesAddress = LLVM.PointerType(pointee: type).constPointerNull()
            }

            let length = gen.i64.constant(values.count)

            let sliceType = LLVM.StructType(elementTypes: [LLVM.PointerType(pointee: type), gen.word, gen.word], in: gen.module.context)
            var slice = sliceType.undef()
            valuesAddress = gen.b.buildInBoundsGEP(valuesAddress, indices: indices) // makes this a pointer
            slice = gen.b.buildInsertValue(aggregate: slice, element: valuesAddress, index: 0) // raw
            slice = gen.b.buildInsertValue(aggregate: slice, element: length, index: 1) // len
            slice = gen.b.buildInsertValue(aggregate: slice, element: gen.i64.constant(0xDEADC0DE), index: 2) // cap

            return slice
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
