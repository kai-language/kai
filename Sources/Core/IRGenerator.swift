
import LLVM

// sourcery:noinit
struct IRGenerator {

    var package: SourcePackage
    var file: SourceFile
    var context: Context

    var module: Module
    var b: IRBuilder

    init(file: SourceFile) {
        self.package = file.package
        self.file = file
        self.context = Context(mangledNamePrefix: "", previous: nil)
        self.module = package.module
        self.b = package.builder
    }

    // sourcery:noinit
    class Context {
        var mangledNamePrefix: String
        var previous: Context?

        init(mangledNamePrefix: String, previous: Context?) {
            self.mangledNamePrefix = mangledNamePrefix
            self.previous = previous
        }
    }

    mutating func pushContext(scopeName: String) {
        context = Context(mangledNamePrefix: mangle(scopeName), previous: context)
    }

    mutating func popContext() {
        context = context.previous!
    }

    func mangle(_ name: String) -> String {
        return (context.mangledNamePrefix.isEmpty ? "" : context.mangledNamePrefix + ".") + name
    }
}

extension IRGenerator {

    mutating func generate() {
        if !package.isInitialPackage {
            pushContext(scopeName: dropExtension(path: file.pathFirstImportedAs))
        }

        for node in file.nodes {
            emit(topLevelStmt: node)
        }

        if !package.isInitialPackage {
            popContext()
        }
    }

    mutating func emit(topLevelStmt stmt: TopLevelStmt) {

        switch stmt {
        case is Import,
             is Library:
            return
        case let f as Foreign:
            emit(foreign: f)
        case let d as DeclBlock: // #callconv "c" { ... }
            emit(declBlock: d)
        case let d as Declaration:
            emit(declaration: d)
        default:
            print("Warning: statement didn't codegen: \(stmt)")
        }
    }

    mutating func emit(declBlock b: DeclBlock) {
        for decl in b.decls {
            emit(declaration: decl)
        }
    }

    mutating func emit(constantDecl decl: Declaration) {
        if decl.values.isEmpty {
            // this is in a decl block of some sort

            for entity in decl.entities {
                if let fn = entity.type as? ty.Function {
                    let function = b.addFunction(decl.linkname ?? entity.name, type: canonicalize(fn))
                    switch decl.callconv {
                    case nil:
                        break
                    case "c"?:
                        function.callingConvention = .c
                    default:
                        fatalError("Unimplemented or unsupported calling convention \(decl.callconv!)")
                    }
                    entity.value = function
                } else {
                    var globalValue = b.addGlobal(decl.linkname ?? entity.name, type: canonicalize(entity.type!))
                    globalValue.isExternallyInitialized = true
                    globalValue.isGlobalConstant = true
                    entity.value = globalValue
                }
            }
            return
        }

        if decl.values.count == 1, let call = decl.values.first as? Call {
            if decl.entities.count > 1 {
                // TODO: Test this.
                let aggregate = emit(call: call) as! Constant<Struct>

                for (index, entity) in decl.entities.enumerated()
                    where entity !== Entity.anonymous
                {
                    entity.value = aggregate.getElement(indices: [index])
                }
            } else {

                decl.entities[0].value = emit(call: call)
            }
            return
        }

        for (entity, value) in zip(decl.entities, decl.values) {
            if let type = entity.type as? ty.Metatype {
                let irType = b.createStruct(name: mangle(entity.name))

                switch type.instanceType {
                case let type as ty.Struct:
                    var irTypes: [IRType] = []
                    for field in type.fields {
                        let fieldType = canonicalize(field.type)
                        irTypes.append(fieldType)
                    }
                    irType.setBody(irTypes)
                    type.ir.val = irType

                default:
                    // Type alias
                    break
                }
                return
            }

            var value = emit(expr: value, name: entity.name)
            // functions are already global
            if !value.isAFunction {
                var globalValue = b.addGlobal(mangle(entity.name), initializer: value)
                globalValue.isGlobalConstant = true
                value = globalValue
            }

            entity.value = value
        }
    }

    mutating func emit(variableDecl decl: Declaration) {
        if decl.values.count == 1, let call = decl.values.first as? Call, decl.entities.count > 1 {
            let retType = canonicalize(call.type)
            let stackAggregate = b.buildAlloca(type: retType)
            let aggregate = emit(call: call)
            b.buildStore(aggregate, to: stackAggregate)

            for (index, entity) in decl.entities.enumerated()
                where entity !== Entity.anonymous
            {
                let type = canonicalize(entity.type!)

                if entity.owningScope.isFile {
                    var global = b.addGlobal(mangle(entity.name), type: type)
                    global.initializer = type.undef()
                    entity.value = global
                } else {
                    let stackValue = b.buildAlloca(type: type, name: entity.name)
                    let rvaluePtr = b.buildStructGEP(stackAggregate, index: index)
                    let rvalue = b.buildLoad(rvaluePtr)

                    b.buildStore(rvalue, to: stackValue)

                    entity.value = stackValue
                }
            }
            return
        }

        if decl.values.isEmpty {
            for entity in decl.entities {
                let type = canonicalize(entity.type!)
                if entity.owningScope.isFile {
                    var global = b.addGlobal(mangle(entity.name), type: type)
                    global.initializer = type.undef()
                    entity.value = global
                } else {
                    entity.value = b.buildAlloca(type: type)
                }
            }
            return
        }

        // NOTE: Uninitialized values?
        assert(decl.entities.count == decl.values.count)
        for (entity, value) in zip(decl.entities, decl.values) {
            if let type = entity.type as? ty.Metatype {
                let irType = b.createStruct(name: mangle(entity.name))

                switch type.instanceType {
                case let type as ty.Struct:
                    var irTypes: [IRType] = []
                    for field in type.fields {
                        let fieldType = canonicalize(field.type)
                        irTypes.append(fieldType)
                    }
                    irType.setBody(irTypes)
                    type.ir.val = irType

                default:
                    preconditionFailure()
                }
                return
            }

            let type = canonicalize(entity.type!)

            if Options.instance.flags.contains(.emitIr) {
                if let endOfAlloca = b.insertBlock?.instructions.first(where: { !$0.isAAllocaInst }) {
                    b.position(endOfAlloca, block: b.insertBlock!)
                }
            }

            let value = emit(expr: value, name: entity.name)
            if entity.owningScope.isFile {
                var global = b.addGlobal(mangle(entity.name), type: type)
                global.initializer = type.undef()
                entity.value = global

                if Options.instance.flags.contains(.emitIr) {
                    b.positionAtEnd(of: b.insertBlock!)
                }
            } else {
                let stackValue = b.buildAlloca(type: type, name: mangle(entity.name))
                
                entity.value = stackValue

                if Options.instance.flags.contains(.emitIr) {
                    b.positionAtEnd(of: b.insertBlock!)
                }

                b.buildStore(value, to: stackValue)
            }
        }
    }

    mutating func emit(foreign: Foreign) {
        emit(declaration: foreign.decl as! Declaration)
    }

    mutating func emit(declaration: Declaration) {

        if declaration.isConstant {
            emit(constantDecl: declaration)
        } else {
            emit(variableDecl: declaration)
        }
    }

    mutating func emit(statement stmt: Stmt) {
        switch stmt {
        case is Empty: return
        case let ret as Return:
            emit(return: ret)
        case let stmt as ExprStmt:
            // return address so that we don't bother with the load
            _ = emit(expr: stmt.expr, returnAddress: true)
        case let decl as Declaration where decl.isConstant:
            emit(constantDecl: decl)
        case let decl as Declaration where !decl.isConstant:
            emit(variableDecl: decl)
        case let b as DeclBlock:
            emit(declBlock: b)
        case let f as Foreign:
            emit(foreign: f)
        case let assign as Assign:
            emit(assign: assign)
        case let block as Block:
            for stmt in block.stmts {
                emit(statement: stmt)
            }
        case let fór as For:
            emit(for: fór)
        case let íf as If:
            emit(if: íf)
        case let s as Switch:
            emit(switch: s)
        case let b as Branch:
            emit(branch: b)
        default:
            print("Warning: statement didn't codegen: \(stmt)")
            return
        }
    }

    mutating func emit(assign: Assign) {
        if assign.rhs.count == 1, let call = assign.rhs.first as? Call {

            if assign.lhs.count == 1 {
                let rvaluePtr = emit(call: call)
                let lvalueAddress = emit(expr: assign.lhs[0], returnAddress: true)
                let rvalue = b.buildLoad(rvaluePtr)
                b.buildStore(rvalue, to: lvalueAddress)
                return
            }

            let retType = canonicalize(call.type)
            let stackAggregate = b.buildAlloca(type: retType)
            let aggregate = emit(call: call)
            b.buildStore(aggregate, to: stackAggregate)

            for (index, lvalue) in assign.lhs.enumerated()
                where (lvalue as? Ident)?.name != "_"
            {
                let lvalueAddress = emit(expr: lvalue, returnAddress: true)
                let rvaluePtr = b.buildStructGEP(stackAggregate, index: index)
                let rvalue = b.buildLoad(rvaluePtr)
                b.buildStore(rvalue, to: lvalueAddress)
            }
            return
        }

        var rvalues: [IRValue] = []
        for rvalue in assign.rhs {
            let rvalue = emit(expr: rvalue)
            rvalues.append(rvalue)
        }

        for (lvalue, rvalue) in zip(assign.lhs, rvalues)
            where (lvalue as? Ident)?.name != "_"
        {
            let lvalueAddress = emit(expr: lvalue, returnAddress: true)
            b.buildStore(rvalue, to: lvalueAddress)
        }
    }

    mutating func emit(return ret: Return) {
        var values: [IRValue] = []
        for value in ret.results {
            let irValue = emit(expr: value)
            values.append(irValue)
        }

        switch values.count {
        case 1:
            b.buildRet(values[0])
        default:
            b.buildRetAggregate(of: values)
        }
    }

    mutating func emit(parameter param: Parameter) {
        let type = canonicalize(param.entity.type!)

        if Options.instance.flags.contains(.emitIr) {
             if let endOfAlloca = b.insertBlock!.instructions.first(where: { !$0.isAAllocaInst }) {
                 b.position(endOfAlloca, block: b.insertBlock!)
             }
        }

        let stackValue = b.buildAlloca(type: type, name: param.entity.name)

        if Options.instance.flags.contains(.emitIr) {
            b.positionAtEnd(of: b.insertBlock!)
        }

        param.entity.value = stackValue
    }

    mutating func emit(if iff: If) {
        let ln = file.position(for: iff.start).line

        let thenBlock = b.currentFunction!.appendBasicBlock(named: "if.then.ln\(ln)")
        let elseBlock = iff.els.map({ _ in b.currentFunction!.appendBasicBlock(named: "if.else.ln.\(ln)") })
        let postBlock = b.currentFunction!.appendBasicBlock(named: "if.post.ln.\(ln)")

        let cond = emit(expr: iff.cond)
        b.buildCondBr(condition: cond, then: thenBlock, else: elseBlock ?? postBlock)

        b.positionAtEnd(of: thenBlock)
        emit(statement: iff.body)

        if let els = iff.els {
            b.positionAtEnd(of: elseBlock!)
            emit(statement: els)

            if elseBlock!.terminator == nil {
                b.buildBr(postBlock)
            } else if thenBlock.terminator != nil {
                // The if statement is terminating and the post block is unneeded.
                postBlock.removeFromParent()
            }
        }

        if thenBlock.terminator == nil {
            b.positionAtEnd(of: thenBlock)
            b.buildBr(postBlock)
        }

        b.positionAtEnd(of: postBlock)
    }

    mutating func emit(for f: For) {
        let currentFunc = b.currentFunction!

        var loopBody: BasicBlock
        var loopPost: BasicBlock
        var loopCond: BasicBlock?
        var loopStep: BasicBlock?

        if let initializer = f.initializer {
            emit(statement: initializer)
        }

        if let condition = f.cond {
            loopCond = currentFunc.appendBasicBlock(named: "for.cond")
            if f.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            b.buildBr(loopCond!)
            b.positionAtEnd(of: loopCond!)

            let cond = emit(expr: condition)
            b.buildCondBr(condition: cond, then: loopBody, else: loopPost)
        } else {
            if f.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            b.buildBr(loopBody)
        }

        b.positionAtEnd(of: loopBody)
        defer {
            loopPost.moveAfter(b.currentFunction!.lastBlock!)
        }

        f.breakLabel.value = loopCond ?? loopStep ?? loopBody
        f.continueLabel.value = loopPost

        emit(statement: f.body)

        let hasJump = b.insertBlock?.terminator != nil

        if let step = f.step {
            if !hasJump {
                b.buildBr(loopStep!)
            }

            b.positionAtEnd(of: loopStep!)
            emit(statement: step)
            b.buildBr(loopCond!)
        } else if let loopCond = loopCond {
            // `for x < 5 { /* ... */ }` || `for i := 1; x < 5; { /* ... */ }`
            if !hasJump {
                b.buildBr(loopCond)
            }
        } else {
            // `for { /* ... */ }`
            if !hasJump {
                b.buildBr(loopBody)
            }
        }

        b.positionAtEnd(of: loopPost)
    }

    mutating func emit(switch sw: Switch) {
        // NOTE: Also check some sort of flag to ensure things are constant integers otherwise LLVM switch doesn't work
        if sw.match == nil {
            fatalError("Boolean Switch not yet implemented for emission")
        }
        let ln = file.position(for: sw.start).line

        let curFunction = b.currentFunction!
        let curBlock = b.insertBlock!

        let postBlock = curFunction.appendBasicBlock(named: "switch.post.ln.\(ln)")
        defer {
            postBlock.moveAfter(curFunction.lastBlock!)
        }
        sw.label.value = postBlock

        var thenBlocks: [BasicBlock] = []
        for c in sw.cases {
            let ln = file.position(for: c.start).line
            if c.match != nil {
                let thenBlock = curFunction.appendBasicBlock(named: "switch.then.ln.\(ln)")
                thenBlocks.append(thenBlock)
            } else {
                let thenBlock = curFunction.appendBasicBlock(named: "switch.default.ln.\(ln)")
                thenBlocks.append(thenBlock)
            }
        }

        let value = sw.match.map({ emit(expr: $0) }) ?? true.asLLVM()
        var matches: [IRValue] = []
        for (i, c, nextCase) in sw.cases.enumerated().map({ ($0.offset, $0.element, sw.cases[safe: $0.offset + 1]) }) {
            let thenBlock = thenBlocks[i]
            nextCase?.label.value = thenBlocks[safe: i + 1]

            if let match = c.match {
                let val = emit(expr: match)
                matches.append(val)
            }

            b.positionAtEnd(of: thenBlock)

            emit(statement: c.block)

            if b.insertBlock!.terminator == nil {
                b.buildBr(postBlock)
            }
            b.positionAtEnd(of: curBlock)
        }

        let hasDefaultCase = sw.cases.last!.match == nil
        let irSwitch = b.buildSwitch(value, else: hasDefaultCase ? thenBlocks.last! : postBlock, caseCount: thenBlocks.count)
        for (match, block) in zip(matches, thenBlocks) {
            irSwitch.addCase(match, block)
        }

        b.positionAtEnd(of: postBlock)
    }

    mutating func emit(branch: Branch) {
        b.buildBr(branch.target.value as! BasicBlock)
    }

    // MARK: Expressions

    mutating func emit(expr: Expr, returnAddress: Bool = false, name: String = "") -> IRValue {
        switch expr {
        case is Nil:
            return canonicalize(expr.type as! ty.Pointer).null()
        case let lit as BasicLit:
            return emit(lit: lit, returnAddress: returnAddress, name: name)
        case let lit as CompositeLit:
            return emit(lit: lit, returnAddress: returnAddress, name: name)
        case let ident as Ident:
            return emit(ident: ident, returnAddress: returnAddress)
        case let paren as Paren:
            return emit(expr: paren.element, returnAddress: returnAddress, name: name)
        case let unary as Unary:
            return emit(unary: unary)
        case let binary as Binary:
            return emit(binary: binary)
        case let ternary as Ternary:
            return emit(ternary: ternary)
        case let fn as FuncLit:
            return emit(funcLit: fn, name: name)
        case let call as Call:
            return emit(call: call)
        case let cast as Cast:
            return emit(cast: cast)
        case let autocast as Autocast:
            return emit(autocast: autocast)
        case let sel as Selector:
            return emit(selector: sel, returnAddress: returnAddress)
        case let sub as Subscript:
            return emit(subscript: sub, returnAddress: returnAddress)
        default:
            preconditionFailure()
        }
    }

    mutating func emit(lit: BasicLit, returnAddress: Bool, name: String) -> IRValue {
        if lit.token == .string {
            let value = lit.constant as! String
            let bytes = value.utf8.count
            let constant = b.buildGlobalStringPtr(value)

            let stackAlloc = b.buildAlloca(type: LLVM.ArrayType(elementType: IntType.int8, count: bytes))
            let stackAllocPtr = b.buildGEP(stackAlloc, indices: [0, 0])
            let newBuff = b.buildBitCast(stackAllocPtr, type: LLVM.PointerType.toVoid)
            let constantPtr = b.buildBitCast(constant, type: LLVM.PointerType.toVoid)
            b.buildMemcpy(newBuff, constantPtr, count: bytes)

            let irType = canonicalize(lit.type)
            var ir = irType.undef()

            ir = b.buildInsertValue(aggregate: ir, element: newBuff, index: 0)
            ir = b.buildInsertValue(aggregate: ir, element: bytes, index: 1) // len
            // NOTE: since the raw buffer is stack allocated, we need to set the
            // capacity to `0`. Then, any call that needs to realloc can instead
            // malloc a new buffer.
            ir = b.buildInsertValue(aggregate: ir, element: 0, index: 2) // cap

            if returnAddress {
                // NOTE: typically, a literal is stored in a declaration. But in
                // the cases where a literal's address is needed there won't be
                // an lvalue to store it in. In these cases, we will store it in
                // an anonymous variable on the stack.
                let stringAlloca = b.buildAlloca(type: canonicalize(ty.string))
                _ = b.buildStore(ir, to: stringAlloca)
                return stringAlloca
            }

            return ir
        }

        let type = canonicalize(lit.type)
        switch type {
        case let type as IntType:
            let val = type.constant(lit.constant as! UInt64)
            return val
        case let type as FloatType:
            if lit.token == .int {
                let val = Double(lit.constant as! UInt64)
                return type.constant(val)
            }
            return type.constant(lit.constant as! Double)
        default:
            preconditionFailure()
        }
    }

    mutating func emit(lit: CompositeLit, returnAddress: Bool, name: String) -> IRValue {
        switch lit.type {
        case let type as ty.Struct:
            let irType = canonicalize(type)
            var ir = irType.undef()
            for el in lit.elements {
                let val = emit(expr: el.value)
                ir = b.buildInsertValue(aggregate: ir, element: val, index: el.structField!.index)
            }
            return ir

        case let type as ty.Array:
            let irType = canonicalize(type)
            var ir = irType.undef()
            for (index, el) in lit.elements.enumerated() {
                let val = emit(expr: el.value)
                ir = b.buildInsertValue(aggregate: ir, element: val, index: index)
            }
            return ir

        case let type as ty.DynamicArray:
            let irType = canonicalize(type)
            var ir = irType.undef()
            let elements = lit.elements.map {
                emit(expr: $0.value)
            }

            let elementType = canonicalize(type.elementType)
            var constant = b.addGlobal("array.lit", initializer: LLVM.ArrayType.constant(elements, type: elementType))
            constant.isGlobalConstant = true

            let stackAlloc = b.buildAlloca(type: LLVM.ArrayType(elementType: elementType, count: type.initialLength))
            let stackAllocPtr = b.buildGEP(stackAlloc, indices: [0, 0])
            let newBuff = b.buildBitCast(stackAllocPtr, type: LLVM.PointerType.toVoid)
            let constantPtr = b.buildBitCast(constant, type: LLVM.PointerType.toVoid)
            let bytes = (type.initialLength * (type.elementType.width ?? 8)).round(upToNearest: 8) / 8
            b.buildMemcpy(newBuff, constantPtr, count: bytes)

            let newBuffCast = b.buildBitCast(newBuff, type: LLVM.PointerType(pointee: elementType))
            ir = b.buildInsertValue(aggregate: ir, element: newBuffCast, index: 0)
            ir = b.buildInsertValue(aggregate: ir, element: bytes, index: 1) // len
            // NOTE: since the raw buffer is stack allocated, we need to set the
            // capacity to `0`. Then, any call that needs to realloc can instead
            // malloc a new buffer.
            ir = b.buildInsertValue(aggregate: ir, element: 0, index: 2) // cap

            return ir

        default:
            preconditionFailure()
        }
    }

    mutating func emit(ident: Ident, returnAddress: Bool) -> IRValue {
        if returnAddress || ident.entity.type! is ty.Function {
            return ident.entity.value!
        }
        if ident.entity.isConstant {
            switch ident.type {
            case let type as ty.Integer:
                return canonicalize(type).constant(ident.constant as! UInt64)
            case let type as ty.UntypedInteger:
                return canonicalize(type).constant(ident.constant as! UInt64)
            case let type as ty.FloatingPoint:
                return canonicalize(type).constant(ident.constant as! Double)
            case let type as ty.UntypedFloatingPoint:
                return canonicalize(type).constant(ident.constant as! Double)
            default:
                break
            }
        }

        if ident.entity.isBuiltin {
            assert(!returnAddress)
            let builtin = builtinEntities.first(where: { $0.entity === ident.entity })!
            return builtin.gen(b)
        }

        return b.buildLoad(ident.entity.value!)
    }

    mutating func emit(unary: Unary) -> IRValue {
        let val = emit(expr: unary.element, returnAddress: unary.op == .and)
        switch unary.op {
        case .add:
            return val
        case .sub:
            return b.buildNeg(val)
        case .lss:
            return b.buildLoad(val)
        case .not:
            return b.buildNot(val)
        case .and:
            return val
        default:
            preconditionFailure()
        }
    }

    mutating func emit(binary: Binary) -> IRValue {
        var lhs = emit(expr: binary.lhs)
        var rhs = emit(expr: binary.rhs)
        if let lcast = binary.irLCast {
            lhs = b.buildCast(lcast, value: lhs, type: canonicalize(binary.rhs.type))
        }
        if let rcast = binary.irRCast {
            rhs = b.buildCast(rcast, value: rhs, type: canonicalize(binary.lhs.type))
        }

        switch binary.irOp! {
        case .icmp:
            let isSigned = (binary.lhs.type as? ty.Integer)?.isSigned ?? true // if type isn't an int it's a ptr
            var pred: IntPredicate
            switch binary.op {
            case .lss: pred = isSigned ? .signedLessThan : .unsignedLessThan
            case .gtr: pred = isSigned ? .signedGreaterThan : .unsignedGreaterThan
            case .leq: pred = isSigned ? .signedLessThanOrEqual : .unsignedLessThanOrEqual
            case .geq: pred = isSigned ? .signedGreaterThanOrEqual : .unsignedGreaterThanOrEqual
            case .eql: pred = .equal
            case .neq: pred = .notEqual
            default:   preconditionFailure()
            }
            return b.buildICmp(lhs, rhs, pred)
        case .fcmp:
            var pred: RealPredicate
            switch binary.op {
            case .lss: pred = .orderedLessThan
            case .gtr: pred = .orderedGreaterThan
            case .leq: pred = .orderedLessThanOrEqual
            case .geq: pred = .orderedGreaterThanOrEqual
            case .eql: pred = .orderedEqual
            case .neq: pred = .orderedNotEqual
            default:   preconditionFailure()
            }
            return b.buildFCmp(lhs, rhs, pred)
        default:
            if binary.isPointerArithmetic {
                switch binary.op {
                case .add, .sub:
                    if binary.op == .sub {
                        rhs = b.buildNeg(rhs)
                    }
                    return b.buildGEP(lhs, indices: [rhs])
                default: preconditionFailure()
                }
            }
            return b.buildBinaryOperation(binary.irOp, lhs, rhs)
        }
    }

    mutating func emit(ternary: Ternary) -> IRValue {
        let cond = emit(expr: ternary.cond)
        let then = ternary.then.map({ emit(expr: $0) })
        let els  = emit(expr: ternary.els)
        return b.buildSelect(cond, then: then ?? cond, else: els)
    }

    mutating func emit(call: Call) -> IRValue {
        switch call.checked! {
        case .builtinCall(let builtin):
            return builtin.generate(builtin, call.args, &self)
        case .call:
            let callee = emit(expr: call.fun, returnAddress: !(call.fun.type is ty.Pointer))
            let args = call.args.map({ emit(expr: $0) })
            return b.buildCall(callee, args: args)
        case .specializedCall(let specialization):
            let args = call.args.map({ emit(expr: $0) })
            return b.buildCall(specialization.llvm!, args: args)
        }
    }

    mutating func emit(autocast: Autocast) -> IRValue {
        let val = emit(expr: autocast.expr, returnAddress: autocast.expr.type is ty.Array)
        return b.buildCast(autocast.op, value: val, type: canonicalize(autocast.type))
    }

    mutating func emit(cast: Cast) -> IRValue {
        let val = emit(expr: cast.expr, returnAddress: cast.expr.type is ty.Array)
        return b.buildCast(cast.op, value: val, type: canonicalize(cast.type))
    }

    mutating func emit(funcLit fn: FuncLit, name: String) -> Function {
        switch fn.checked! {
        case .regular:
            let function = b.addFunction(mangle(name), type: canonicalize(fn.type) as! FunctionType)
            let prevBlock = b.insertBlock

            let entryBlock = function.appendBasicBlock(named: "entry")
            b.positionAtEnd(of: entryBlock)

            for (param, var irParam) in zip(fn.params.list, function.parameters) {
                irParam.name = param.entity.name
                emit(parameter: param)

                b.buildStore(irParam, to: param.entity.value!)
            }

            pushContext(scopeName: name)
            emit(statement: fn.body)
            popContext()

            if b.insertBlock?.terminator == nil, fn.results.types.first!.type!.lower() == ty.void {
                b.buildRetVoid()
            }

            if let prevBlock = prevBlock {
                b.positionAtEnd(of: prevBlock)
            }

            return function

        case .polymorphic(_, let specializations):
            for specialization in specializations {
                let suffix = specialization.specializedTypes
                    .reduce("", { $0 + "$" + $1.description })
                specialization.llvm = emit(funcLit: specialization.generatedFunctionNode, name: name + suffix)
            }
            return module.firstFunction! // dummy value. It doesn't matter.
        }
    }

    mutating func emit(selector sel: Selector, returnAddress: Bool) -> IRValue {
        switch sel.checked! {
        case .invalid: fatalError()
        case .file(let entity):
            if entity.type is ty.Function {
                return entity.value!
            }
            if entity.isConstant {
                switch sel.type {
                case let type as ty.Integer:
                    return canonicalize(type).constant(sel.constant as! UInt64)
                case let type as ty.UntypedInteger:
                    return canonicalize(type).constant(sel.constant as! UInt64)
                case let type as ty.FloatingPoint:
                    return canonicalize(type).constant(sel.constant as! Double)
                case let type as ty.UntypedFloatingPoint:
                    return canonicalize(type).constant(sel.constant as! Double)
                default:
                    break
                }
            }
            let val = b.buildLoad(entity.value!)
            if let cast = sel.cast {
                return b.buildCast(cast, value: val, type: canonicalize(sel.type))
            }
            return val
        case .struct(let field):
            let aggregate = emit(expr: sel.rec, returnAddress: true)
            let fieldAddress = b.buildStructGEP(aggregate, index: field.index)
            if returnAddress {
                return fieldAddress
            }
            let val = b.buildLoad(fieldAddress)
            if let cast = sel.cast {
                return b.buildCast(cast, value: val, type: canonicalize(sel.type))
            }
            return val
        case .array(let member):
            let aggregate = emit(expr: sel.rec, returnAddress: true)
            let index = member.rawValue
            let fieldAddress = b.buildStructGEP(aggregate, index: index)
            if returnAddress {
                return fieldAddress
            }
            let val = b.buildLoad(fieldAddress)
            if let cast = sel.cast {
                return b.buildCast(cast, value: val, type: canonicalize(sel.type))
            }
            return val
        }
    }

    mutating func emit(subscript sub: Subscript, returnAddress: Bool) -> IRValue {
        let aggregate: IRValue
        let index = emit(expr: sub.index)

        let indicies: [IRValue]

        // NOTE: Pointers need to have the address loaded and arrays must use their address
        switch sub.checked! {
        case .array:
            aggregate = emit(expr: sub.rec, returnAddress: true)
            indicies = [0, index]

        case .dynamicArray:
            let structPtr = emit(expr: sub.rec, returnAddress: true)
            let arrayPtr = b.buildStructGEP(structPtr, index: 0)
            aggregate = b.buildLoad(arrayPtr)
            indicies = [index]

        case .pointer:
            aggregate = emit(expr: sub.rec)
            indicies = [index]
        }

        let val = b.buildInBoundsGEP(aggregate, indices: indicies)
        if returnAddress {
            return val
        }
        return b.buildLoad(val)
    }
}

func canonicalize(_ void: ty.Void) -> VoidType {
    return VoidType()
}

func canonicalize(_ boolean: ty.Boolean) -> IntType {
    return IntType.int1
}

func canonicalize(_ integer: ty.Integer) -> IntType {
    return IntType(width: integer.width!)
}

func canonicalize(_ float: ty.FloatingPoint) -> FloatType {
    switch float.width! {
    case 16: return FloatType.half
    case 32: return FloatType.float
    case 64: return FloatType.double
    case 80: return FloatType.x86FP80
    case 128: return FloatType.fp128
    default: fatalError()
    }
}

func canonicalize(_ string: ty.KaiString) -> LLVM.StructType {
    let cStringType = LLVM.PointerType(pointee: IntType.int8)
    // Memory size is in bytes but LLVM types are in bits
    let systemWidthType = LLVM.IntType(width: MemoryLayout<Int>.size * 8)
    return LLVM.StructType(elementTypes: [cStringType, systemWidthType, systemWidthType])
}

func canonicalize(_ pointer: ty.Pointer) -> LLVM.PointerType {
    return LLVM.PointerType(pointee: canonicalize(pointer.pointeeType))
}

func canonicalize(_ array: ty.Array) -> LLVM.ArrayType {
    return LLVM.ArrayType(elementType: canonicalize(array.elementType), count: array.length)
}

func canonicalize(_ array: ty.DynamicArray) -> LLVM.StructType {
    let element = LLVM.PointerType(pointee: canonicalize(array.elementType))
    // Memory size is in bytes but LLVM types are in bits
    let systemWidthType = LLVM.IntType(width: MemoryLayout<Int>.size * 8)
    // { Element type, Length, Capacity }
    return LLVM.StructType(elementTypes: [element, systemWidthType, systemWidthType])
}

func canonicalize(_ fn: ty.Function) -> FunctionType {
    var paramTypes: [IRType] = []

    let requiredParams = fn.isVariadic ? fn.params[..<(fn.params.endIndex - 1)] : ArraySlice(fn.params)
    for param in requiredParams {
        let type = canonicalize(param)
        paramTypes.append(type)
    }
    let retType = canonicalize(fn.returnType)
    return FunctionType(argTypes: paramTypes, returnType: retType, isVarArg: fn.isCVariadic)
}

/// - Returns: A StructType iff tuple.types > 1
func canonicalize(_ tuple: ty.Tuple) -> IRType {
    let types = tuple.types.map(canonicalize)
    switch types.count {
    case 1:
        return types[0]
    default:
        return LLVM.StructType(elementTypes: types, isPacked: true)
    }
}

func canonicalize(_ struc: ty.Struct) -> LLVM.StructType {
    return struc.ir.val!
}

func canonicalize(_ integer: ty.UntypedInteger) -> IntType {
    return IntType(width: integer.width!)
}

func canonicalize(_ float: ty.UntypedFloatingPoint) -> FloatType {
    return FloatType.double
}

func canonicalize(_ type: Type) -> IRType {

    switch type {
    case let type as ty.Void:
        return canonicalize(type)
    case let type as ty.Boolean:
        return canonicalize(type)
    case let type as ty.Integer:
        return canonicalize(type)
    case let type as ty.FloatingPoint:
        return canonicalize(type)
    case let type as ty.KaiString:
        return canonicalize(type)
    case let type as ty.Pointer:
        return canonicalize(type)
    case let type as ty.Array:
        return canonicalize(type)
    case let type as ty.DynamicArray:
        return canonicalize(type)
    case let type as ty.Function:
        return canonicalize(type)
    case let type as ty.Struct:
        return canonicalize(type)
    case let type as ty.Tuple:
        return canonicalize(type)
    case let type as ty.UntypedInteger:
        return canonicalize(type)
    case let type as ty.UntypedFloatingPoint:
        return canonicalize(type)
    case is ty.UntypedNil:
        fatalError("Untyped nil should be constrained to target type")
    case is ty.Polymorphic:
        fatalError()
    default:
        preconditionFailure()
    }
}

