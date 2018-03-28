
import LLVM

extension Scope {

    static let global: Scope = {

        return Scope(members: globalBuiltins.toDictionary(with: { $0.name }))
    }()
}

extension builtin {

    /// - Note: The namespacing here is used by code gen to generate things that are to be inserted into the global scope.
    enum globals {

        static let void = BuiltinType(entity: .void, type: ty.Void())
        static let any  = BuiltinType(entity: .any,  type: ty.Anyy())

        static let bool   = BuiltinType(entity:  .bool,   type: ty.Boolean(width: 1))
        static let rawptr = BuiltinType(entity:  .rawptr, type: ty.Pointer(u8.type))
        static let string = BuiltinType(entity:  .string, type: ty.Slice(u8.type))

        static let f32 = BuiltinType(entity: .f32, type: ty.Float(width: 32))
        static let f64 = BuiltinType(entity: .f64, type: ty.Float(width: 64))

        static let b8  = BuiltinType(entity: .b8,  type: ty.Boolean(width: 8))
        static let b16 = BuiltinType(entity: .b16, type: ty.Boolean(width: 16))
        static let b32 = BuiltinType(entity: .b32, type: ty.Boolean(width: 32))
        static let b64 = BuiltinType(entity: .b64, type: ty.Boolean(width: 64))
        static let i8  = BuiltinType(entity: .i8,  type: ty.Integer(width: 8,  isSigned: true))
        static let i16 = BuiltinType(entity: .i16, type: ty.Integer(width: 16, isSigned: true))
        static let i32 = BuiltinType(entity: .i32, type: ty.Integer(width: 32, isSigned: true))
        static let i64 = BuiltinType(entity: .i64, type: ty.Integer(width: 64, isSigned: true))
        static let u8  = BuiltinType(entity: .u8,  type: ty.Integer(width: 8,  isSigned: false))
        static let u16 = BuiltinType(entity: .u16, type: ty.Integer(width: 16, isSigned: false))
        static let u32 = BuiltinType(entity: .u32, type: ty.Integer(width: 32, isSigned: false))
        static let u64 = BuiltinType(entity: .u64, type: ty.Integer(width: 64, isSigned: false))

        // FIXME: For builtin entities we need to allow the desired type to propigate the correct boolean type into here, in case it's a non 1 width boolean
        static let trué: BuiltinEntity = BuiltinEntity(name: "true", type: bool.type, gen: { IntType(width: 1, in: $0.module.context).constant(1) })
        static let falsé: BuiltinEntity = BuiltinEntity(name: "false", type: bool.type, gen: { IntType(width: 1, in: $0.module.context).constant(0) })

        static var panic: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("panic", type: ty.Function.make([ty.string], [ty.void])),
            generate: { (function, returnAddress, call, gen) -> IRValue in
                Swift.assert(!returnAddress)
                let b = gen.b

                // TODO: do something with the message
                let msg = call.args[safe: 0].map({ gen.emit(expr: $0) }) ?? gen.emit(constantString: "")
                let location = gen.package.position(for: call.start)
                let filename = b.buildGlobalStringPtr(location?.filename ?? "unknown")
                let line = gen.i32.constant(location?.line ?? 0)
                let fmt = b.buildGlobalStringPtr("panic at %s:%u\n    %s\n")
                _ = b.buildCall(gen.printf, args: [fmt, filename, line, b.buildExtractValue(msg, index: 0)])
                if !compiler.options.isTestMode {
                    _ = b.buildCall(gen.trap, args: [])
                } else {
                    b.buildStore(gen.i1.constant(1), to: gen.testAsserted)
                }
                // FIXME: We need to have an unreachable return type and unreachable directive
                b.buildBr(gen.context.returnBlock!)

                return VoidType().undef()
            },
            onCallCheck: { (checker, call) -> Operand in
                var dependencies: Set<Entity> = []
                if let msg = call.args[safe: 0] {
                    let op = checker.check(expr: msg, desiredType: ty.string)
                    dependencies.formUnion(op.dependencies)
                    guard convert(op.type, to: ty.string, at: msg) else {
                        checker.reportError("Cannot convert value '\(msg)' to expected argument type '\(ty.string)'", at: call.args[0].start,
                                            attachNotes: "In call to builtin 'assert'")
                        return Operand.invalid
                    }
                }

                return Operand(mode: .computed, expr: call, type: ty.void, constant: nil, dependencies: dependencies)
            }
        )

        static var sizeof: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("sizeof", type: builtin.types.sizeOf.type),
            generate: builtin.types.sizeOf.generate,
            onCallCheck: builtin.types.sizeOf.onCallCheck
        )

        static var assert: BuiltinFunction = BuiltinFunction(
            entity: Entity.makeBuiltin("assert", type: ty.Function.make([ty.bool, ty.string], [ty.void])),
            generate: { (function, returnAddress, call, gen) -> IRValue in
                Swift.assert(!returnAddress)
                let b = gen.b

                let function = gen.b.currentFunction!

                let cond = gen.emit(expr: call.args[0])
                let fail = function.appendBasicBlock(named: "assert.failure", in: gen.module.context)
                let pass = function.appendBasicBlock(named: "assert.pass", in: gen.module.context)

                b.buildCondBr(condition: b.buildTruncOrBitCast(cond, type: gen.i1), then: pass, else: fail)

                b.positionAtEnd(of: fail)
                let msg = call.args[safe: 1].map({ gen.emit(expr: $0) }) ?? gen.emit(constantString: "")
                let location = gen.package.position(for: call.start)
                let condition = b.buildGlobalStringPtr(call.args[0].description)
                let filename = b.buildGlobalStringPtr(location?.filename ?? "unknown")
                let line = gen.i32.constant(location?.line ?? 0)
                let fmt = b.buildGlobalStringPtr("assertion failed at %s:%u (%s)\n    %s\n")
                _ = b.buildCall(gen.printf, args: [fmt, filename, line, condition, b.buildExtractValue(msg, index: 0)])
                // do something with the message
                if !compiler.options.isTestMode {
                    _ = b.buildCall(gen.trap, args: [])
                } else {
                    b.buildStore(gen.i1.constant(1), to: gen.testAsserted)
                }
                b.buildBr(gen.context.returnBlock!)

                b.positionAtEnd(of: pass)

                return VoidType().undef()
            },
            onCallCheck: { (checker, call) -> Operand in
                guard !call.args.isEmpty && call.args.count <= 2 else {
                    checker.reportError("Expected arguments (bool, string)", at: call.start,
                                        attachNotes: "in call to builtin 'assert'")
                    return Operand.invalid
                }

                var dependencies: Set<Entity> = []
                let cond = checker.check(expr: call.args[0], desiredType: ty.bool)
                dependencies.formUnion(cond.dependencies)
                guard convert(cond.type, to: ty.bool, at: call.args[0]) else {
                    checker.reportError("Cannot convert value '\(call.args[0])' to expected argument type '\(ty.bool)'", at: call.args[0].start,
                                        attachNotes: "In call to builtin 'assert'")
                    return Operand.invalid
                }

                if let msg = call.args[safe: 1] {
                    let op = checker.check(expr: msg, desiredType: ty.string)
                    dependencies.formUnion(op.dependencies)
                    guard convert(op.type, to: ty.string, at: msg) else {
                        checker.reportError("Cannot convert value '\(msg)' to expected argument type '\(ty.string)'", at: call.args[0].start,
                                            attachNotes: "In call to builtin 'assert'")
                        return Operand.invalid
                    }
                }

                return Operand(mode: .computed, expr: call, type: ty.void, constant: nil, dependencies: dependencies)
            }
        )
    }
}
