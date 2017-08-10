
import LLVM

enum stdlib {

    static var module: Module = {
        return Module(name: "_kai_stdlib")
    }()

    static var builder: IRBuilder = {
        let builder = IRBuilder(module: module)

        // TODO: Declare stdlib builtins

        return builder
    }()
}

// sourcery:noinit
struct IRGenerator {

    var package: SourcePackage
    var file: SourceFile
    var context: Context

    var module: Module
    var builder: IRBuilder

    init(file: SourceFile) {
        self.package = file.package
        self.file = file
        self.context = Context(mangledNamePrefix: "", previous: nil)
        self.module = package.module
        self.builder = package.builder
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

    mutating func emit(topLevelStmt: TopLevelStmt) {

        switch topLevelStmt {
        case is Import,
             is Library:
            return
        case let f as Foreign:
            emit(anyDecl: f, isForeign: true)
        case let d as DeclBlock: // #callconv "c" { ... }
            emit(anyDecl: d, isForeign: false)
        case let d as Declaration where d.isConstant:
            emit(constantDecl: d)
        case let d as Declaration where !d.isConstant:
            emit(variableDecl: d)
        default:
            fatalError()
        }
    }

    mutating func emit(constantDecl decl: Declaration) {
        assert(!decl.values.isEmpty)
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
                let irType = builder.createStruct(name: mangle(entity.name))

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

            let value = emit(expr: value)
            var globalValue = builder.addGlobal(mangle(entity.name), initializer: value)
            globalValue.isGlobalConstant = true
            entity.value = globalValue
        }
    }

    mutating func emit(variableDecl decl: Declaration) {
        if decl.values.count == 1, let call = decl.values.first as? Call {
            let retType = canonicalize(call.type)
            let stackAggregate = builder.buildAlloca(type: retType)
            let aggregate = emit(call: call)
            builder.buildStore(aggregate, to: stackAggregate)

            for (index, entity) in decl.entities.enumerated()
                where entity !== Entity.anonymous
            {
                let type = canonicalize(entity.type!)
                let stackValue = builder.buildAlloca(type: type, name: entity.name)
                let rvaluePtr = builder.buildStructGEP(stackAggregate, index: index)
                let rvalue = builder.buildLoad(rvaluePtr)

                builder.buildStore(rvalue, to: stackValue)

                entity.value = stackValue
            }
            return
        }

        if decl.values.isEmpty {
            for entity in decl.entities {
                let type = canonicalize(entity.type!)
                entity.value = builder.buildAlloca(type: type)
            }
            return
        }

        // NOTE: Uninitialized values?
        assert(decl.entities.count == decl.values.count)
        for (entity, value) in zip(decl.entities, decl.values) {
            if let type = entity.type as? ty.Metatype {
                let irType = builder.createStruct(name: mangle(entity.name))

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
                if let endOfAlloca = builder.insertBlock?.instructions.first(where: { !$0.isAAllocaInst }) {
                    builder.position(endOfAlloca, block: builder.insertBlock!)
                }
            }

            let stackValue = builder.buildAlloca(type: type, name: mangle(entity.name))

            if Options.instance.flags.contains(.emitIr) {
                builder.positionAtEnd(of: builder.insertBlock!)
            }

            entity.value = stackValue

            let value = emit(expr: value, name: entity.name)
            builder.buildStore(value, to: stackValue)
        }
    }

    mutating func emit(anyDecl: Decl, isForeign: Bool) {

        switch anyDecl {
        case let f as Foreign:
            emit(anyDecl: f.decl, isForeign: true)

        case let b as DeclBlock:
            fatalError()

        case let d as Declaration:
            fatalError()

        default:
            preconditionFailure()
        }
    }

    mutating func emit(statement stmt: Stmt) {

        switch stmt {
        case is Empty: return
        case let stmt as ExprStmt:
            // return address so that we don't bother with the load
            _ = emit(expr: stmt.expr, returnAddress: true)
        case let decl as Declaration where decl.isConstant:
            emit(constantDecl: decl)
        case let decl as Declaration where !decl.isConstant:
            emit(variableDecl: decl)
        case let d as Decl:
            emit(anyDecl: d, isForeign: false)
        case let block as Block:
            for stmt in block.stmts {
                emit(statement: stmt)
            }
        default:
            return
        }
    }

    mutating func emit(assign: Assign) {
        if assign.rhs.count == 1, let call = assign.rhs.first as? Call {
            let retType = canonicalize(call.type)
            let stackAggregate = builder.buildAlloca(type: retType)
            let aggregate = emit(call: call)
            builder.buildStore(aggregate, to: stackAggregate)

            for (index, lvalue) in assign.lhs.enumerated()
                where (lvalue as? Ident)?.name != "_"
            {
                let lvalueAddress = emit(expr: lvalue, returnAddress: true)
                let rvaluePtr = builder.buildStructGEP(stackAggregate, index: index)
                let rvalue = builder.buildLoad(rvaluePtr)
                builder.buildStore(rvalue, to: lvalueAddress)
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
            builder.buildStore(rvalue, to: lvalueAddress)
        }
    }

    mutating func emit(return ret: Return) {
        var values: [IRValue] = []
        for value in ret.results {
            let irValue = emit(expr: value)
            values.append(irValue)
        }

        switch values.count {
        case 0:
            builder.buildRetVoid()

        case 1:
            builder.buildRet(values[0])

        default:
            builder.buildRetAggregate(of: values)
        }

    }

    mutating func emit(parameter param: Parameter) {
        let type = canonicalize(param.entity.type!)

        if Options.instance.flags.contains(.emitIr) {

             if let endOfAlloca = builder.insertBlock!.instructions.first(where: { !$0.isAAllocaInst }) {
                 builder.position(endOfAlloca, block: builder.insertBlock!)
             }
        }

        let stackValue = builder.buildAlloca(type: type, name: param.entity.name)

        if Options.instance.flags.contains(.emitIr) {
            builder.positionAtEnd(of: builder.insertBlock!)
        }

        param.entity.value = stackValue
    }

    mutating func emit(if iff: If) {
        let cond = emit(expr: iff.cond)

        let ln = file.position(for: iff.start).line

        let thenBlock = builder.currentFunction!.appendBasicBlock(named: "if.then.ln\(ln)")
        let elseBlock = iff.els.map({ _ in builder.currentFunction!.appendBasicBlock(named: "if.else.ln.\(ln)") })
        let postBlock = builder.currentFunction!.appendBasicBlock(named: "if.post.ln.\(ln)")

        if let elseBlock = elseBlock {
            builder.buildCondBr(condition: cond, then: thenBlock, else: elseBlock)
        } else {
            builder.buildCondBr(condition: cond, then: thenBlock, else: postBlock)
        }

        builder.positionAtEnd(of: thenBlock)
        emit(statement: iff.body)

        if let els = iff.els {
            builder.positionAtEnd(of: elseBlock!)
            emit(statement: els)

            if elseBlock!.terminator != nil && thenBlock.terminator != nil {
                postBlock.removeFromParent()

                return
            }
        }

        builder.positionAtEnd(of: postBlock)
    }

    mutating func emit(for f: For) {
        let currentFunc = builder.currentFunction!

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

            builder.buildBr(loopCond!)
            builder.positionAtEnd(of: loopCond!)

            let cond = emit(expr: condition)
            builder.buildCondBr(condition: cond, then: loopBody, else: loopPost)
        } else {
            if f.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step")
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body")
            loopPost = currentFunc.appendBasicBlock(named: "for.post")

            builder.buildBr(loopBody)
        }

        // TODO: Break targets
//        f.breakTarget.val = loopPost
//        f.continueTarget.val = loopCond ?? loopStep ?? loopBody
        builder.positionAtEnd(of: loopBody)
        defer {
            loopPost.moveAfter(builder.currentFunction!.lastBlock!)
        }

        emit(statement: f.body)

        let hasJump = builder.insertBlock?.terminator != nil

        if let step = f.step {
            if !hasJump {
                builder.buildBr(loopStep!)
            }

            builder.positionAtEnd(of: loopStep!)
            emit(statement: step)
            builder.buildBr(loopCond!)
        } else if let loopCond = loopCond {
            // `for x < 5 { /* ... */ }` || `for i := 1; x < 5; { /* ... */ }`
            if !hasJump {
                builder.buildBr(loopCond)
            }
        } else {
            // `for { /* ... */ }`
            if !hasJump {
                builder.buildBr(loopBody)
            }
        }

        builder.positionAtEnd(of: loopPost)
    }

    mutating func emit(switch sw: Switch) {
        fatalError()
    }

    mutating func emit(branch: Branch) {
        fatalError()
    }

    // MARK: Expressions

    mutating func emit(expr: Expr, returnAddress: Bool = false, name: String = "") -> IRValue {
        fatalError()
    }

    mutating func emit(call: Call) -> IRValue {
        fatalError()
    }
}


func canonicalize(_ type: Type) -> IRType {

    switch type {
    case is ty.Void:
        return VoidType()
    case is ty.Boolean:
        return IntType.int1
    case let type as ty.Integer:
        return IntType(width: type.width!)
    case let type as ty.FloatingPoint:
        switch type.width! {
        case 16: return FloatType.half
        case 32: return FloatType.float
        case 64: return FloatType.double
        case 80: return FloatType.x86FP80
        case 128: return FloatType.fp128
        default: fatalError()
        }
    case let type as ty.Pointer:
        return LLVM.PointerType(pointee: canonicalize(type.pointeeType))
    case let type as ty.Function:
        var paramTypes: [IRType] = []

        let requiredParams = type.isVariadic ? type.params[..<(type.params.endIndex - 1)] : ArraySlice(type.params)
        for param in requiredParams {
            let type = canonicalize(param)
            paramTypes.append(type)
        }
        let retType = canonicalize(type.returnType)
        return FunctionType(argTypes: paramTypes, returnType: retType, isVarArg: type.isCVariadic)
    case let type as ty.Struct:
        return type.ir.val!
    case let type as ty.Tuple:
        let types = type.types.map(canonicalize)
        switch types.count {
        case 1:
            return types[0]
        default:
            return LLVM.StructType(elementTypes: types, isPacked: true)
        }
    default:
        fatalError()
    }
}

