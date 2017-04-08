import LLVM

class IRGenerator {

    var file: ASTFile
    var context = Context()

    var checker: Checker
    var llvmPointers:   [Entity: IRValue]  = [:]
    
    let module: Module
    let builder: IRBuilder

    class Context {

        var currentProcedure: Procedure?

        var scope: Scope = .universal

        var escapePoints: EscapePoints?

        struct EscapePoints {
            var `break`: IRValue
            var `continue`: IRValue
        }
    }
    
    init(_ file: ASTFile, checker: Checker) throws {
        self.checker = checker
        self.file = file
        module = Module(name: file.name)
        builder = IRBuilder(module: module)
    }
    
    static func build(for file: ASTFile, checker: Checker) throws -> Module {
        let generator = try IRGenerator(file, checker: checker)
        try generator.emitImported()
        try generator.emitGlobals()

        return generator.module
    }
}

class Procedure {
    let scope: Scope
    let llvm: Function
    var type: FunctionType
    var returnValue: IRValue?
    var deferBlock: BasicBlock?
    var returnBlock: BasicBlock

    init(scope: Scope, llvm: Function, type: FunctionType, returnBlock: BasicBlock, returnValue: IRValue?) {
        self.scope = scope
        self.llvm = llvm
        self.type = type
        self.returnBlock = returnBlock
        self.returnValue = returnValue
    }
}





// MARK: Code Generation

extension IRGenerator {

    func emitImported() throws {
        for entity in file.importedEntities {
            let global = builder.addGlobal(entity.mangledName!, type: entity.type!.canonicalized())
            llvmPointers[entity] = global
        }
    }
    
    func emitGlobals() throws {
        for node in file.nodes {
            switch node {
            case .comment:
                break

            case .declValue:
                emitStmtDeclaration(node)

            case .declImport, .declLibrary:
                break
                
            default:
                print("unsupported type for: \(node.shortName)")
                break
            }
        }
    }
}

extension IRGenerator {

    @discardableResult
    func emitStmt(_ node: AstNode, isLValue: Bool = false) -> IRValue {
        switch node {
        case .comment:
            return VoidType().null()

        case .litString, .litFloat, .litInteger, .litProc, .litCompound:
            return emitExprLiteral(node)

        // FIXME(vdka): Feels a bit hacky.
        case .ident("true", _):
            return IntType.int1.constant(1)

        case .ident("false", _):
            return IntType.int1.constant(0)

        case .ident("nil", _):
            let type = checker.info.types[node]!
            return type.canonicalized().constPointerNull()

        case .ident(let identifier, _):
            let entity = context.scope.lookup(identifier)!
            return builder.buildLoad(llvmPointers[entity]!)

        case .exprSelector(let receiver, let member, _):

            switch receiver {
            case .ident(let ident, _):
                let recvEntity = context.scope.lookup(ident)!

                switch recvEntity.kind {
                case .importName:
                    let entity = recvEntity.childScope!.lookup(member.identifier)!
                    if let val = llvmPointers[entity] {

                        return builder.buildLoad(val)
                    } else {

                        let val = builder.addGlobal(entity.mangledName!, type: entity.type!.canonicalized())
                        llvmPointers[entity] = val

                        return builder.buildLoad(val)
                    }

                default:
                    unimplemented("Selectors for entities of kind \(recvEntity.kind)")
                }

            default:
                unimplemented("Emitting selector on AstNodes of kind \(receiver.shortName)")
            }
        
        case .declValue:
            return emitStmtDeclaration(node)
            
        case .stmtDefer:
            return emitStmtDefer(node)

        case .exprUnary:
            return emitExprOperator(node)

        case .exprBinary:
            return emitExprOperator(node)

        case .exprSubscript:
            return emitExprSubscript(node, isLValue: isLValue)
            
        case .exprCall:
            if checker.info.casts.contains(node) {
                return emitExprCast(node)
            }
            return emitExprCall(node)

        case .exprParen(let expr, _):
            return emitStmt(expr)

        case .stmtExpr(let expr):
            return emitStmt(expr)

        case .stmtAssign:
            return emitStmtAssignment(node)

        case .stmtBlock(let stmts, _):
            pushScope(for: node)
            defer { popScope() }

            for stmt in stmts {
                emitStmt(stmt)
            }
            return VoidType().null()
            
        case .stmtReturn:
            return emitStmtReturn(node)

        case .stmtIf:
            return emitStmtIf(node)

        case .stmtFor:
            return emitStmtFor(node)

        case .stmtBreak:
            return builder.buildBr(context.escapePoints!.break as! BasicBlock)

        case .stmtContinue:
            return builder.buildBr(context.escapePoints!.continue as! BasicBlock)
            
        default:
            fatalError()
        }
    }


    @discardableResult
    func emitExprLiteral(_ node: AstNode) -> IRValue {
        switch node {
        case .litInteger(let val, _):
            let type = checker.info.types[node]!


            //
            // A literal integer can also be a floating point type if constrained to be.
            //

            switch type.canonicalized() {
            case let type as IntType:
                return type.constant(val)

            case let type as FloatType:
                return type.constant(Double(val))

            default:
                fatalError()
            }

        case .litFloat(let val, _):
            let type = checker.info.types[node]!
            return (type.canonicalized() as! FloatType).constant(val)

        case .litString(let val, _):
            return builder.buildGlobalStringPtr(val.escaped)

        case .litCompound(let elements, _):
            let type = checker.info.types[node]!

            if case .array(let underlyingType, _) = type.kind {
                let values = elements.map {
                    emitStmt($0)
                }
                // FIXME(vdka): For literals that do not exactly match the count of the array they are assigned to this emits bad IR.
                return ArrayType.constant(values, type: underlyingType.canonicalized())
            }

            unimplemented("Emitting constants for \(type)")
            
        default:
            fatalError()
        }
    }

    func emitExprCast(_ node: AstNode) -> IRValue {
        guard case .exprCall(let r, let args, _) = node else {
            panic()
        }

        assert(checker.info.casts.contains(node))

        let arg = args.first!

        let argType = checker.info.types[arg]!
        let outType = checker.info.types[r]!.underlyingType!

        let outIrType = outType.canonicalized()

        let argIrVal  = emitStmt(arg)
        if outType.width == argType.width {

            if argType.isFloat && outType.isInteger {
                return builder.buildFPToInt(argIrVal, type: outIrType as! IntType, signed: outType.isSigned)
            } else if argType.isInteger && outType.isFloat {
                return builder.buildIntToFP(argIrVal, type: outIrType as! FloatType, signed: argType.isSigned)
            }

            return builder.buildBitCast(argIrVal, type: outIrType)
        } else if outType.width < argType.width {

            return builder.buildTrunc(argIrVal, type: outIrType)
        } else if outType.width > argType.width, outType.isInteger && argType.isInteger {

            if argType.isSigned {

                return builder.buildSExt(argIrVal, type: outIrType)
            } else {

                return builder.buildZExt(argIrVal, type: outIrType)
            }
        } else if argType.isFloat && outType.isFloat {

            return builder.buildFPCast(argIrVal, type: outIrType)
        } else if argType.isInteger && outType.isFloat {

            return builder.buildIntToFP(argIrVal, type: outIrType as! FloatType, signed: argType.isSigned)
        } else {

            fatalError("I probably missed things")
        }
    }

    func emitStmtIf(_ node: AstNode) -> IRValue {
        guard case .stmtIf(let cond, let thenStmt, let elseStmt, _) = node else {
            panic()
        }

        let curFunction = builder.currentFunction!
        let thenBlock: BasicBlock = curFunction.appendBasicBlock(named: "if.then")
        var elseBlock: BasicBlock?
        let postBlock: BasicBlock

        if elseStmt != nil {
            elseBlock = curFunction.appendBasicBlock(named: "if.else")
        }

        postBlock = curFunction.appendBasicBlock(named: "if.post")

        //
        // Emit the conditional branch
        //

        let condVal = emitExprConditional(for: cond)

        builder.buildCondBr(condition: condVal, then: thenBlock, else: elseBlock ?? postBlock)

        //
        // Emit the `then` block
        //

        builder.positionAtEnd(of: thenBlock)

        emitStmt(thenStmt)

        if !thenBlock.hasTerminatingInstruction {
            builder.buildBr(postBlock)
        }

        if let elseBlock = elseBlock, let elseStmt = elseStmt {

            if (elseStmt.children.last?.isReturn ?? false || elseStmt.isReturn) &&
                (thenStmt.children.last?.isReturn ?? false || thenStmt.isReturn) {

                // If both the if and the else return then there is no need for a post block
                postBlock.removeFromParent()

//                postBlock.delete()
            }

            //
            // Emit the `else` block
            //

            builder.positionAtEnd(of: elseBlock)

            emitStmt(elseStmt)

            if !elseBlock.hasTerminatingInstruction {
                builder.buildBr(postBlock)
            }
        }

        //
        // Set builder position to the end of the `if.post` block
        //

        builder.positionAtEnd(of: postBlock)

        return postBlock
    }

    @discardableResult
    func emitStmtDeclaration(_ node: AstNode) -> IRValue {

        // TODO(vdka): isRuntime? Is that in emission or just checking?
        guard case .declValue(_, let names, _, let values, _) = node else {
            panic(node)
        }

        let decl = checker.info.decls[node]!

        /// This should be a proc call.
        if names.count > 1, values.count == 1, let value = values.first {

            let procRetType = checker.info.types[value]!

            assert(procRetType.isTuple)

            let procRetValue = emitStmt(value)
            let retValue = builder.buildAlloca(type: procRetValue.type)
            builder.buildStore(procRetValue, to: retValue)

            for (index, entity) in decl.entities.enumerated() {
                if entity.name == "_" { continue }
                let irType = entity.type!.canonicalized()

                let rhsIrValuePtr = builder.buildStructGEP(retValue, index: index)

                let rhsIrValue = builder.buildLoad(rhsIrValuePtr)

                let lhsIrValue: IRValue
                if let function = context.currentProcedure?.llvm {
                    lhsIrValue = emitEntryBlockAlloca(in: function, type: irType, named: entity.name, default: rhsIrValue)
                } else {
                    lhsIrValue = emitGlobal(name: entity.name, type: irType, value: rhsIrValue)
                }

                llvmPointers[entity] = lhsIrValue
            }

            return VoidType().null()
        } else if decl.entities.count == 1, let entity = decl.entities.first,
            case .proc = entity.type!.kind, let value = decl.initExprs.first {

            return emitProcedureDefinition(entity, value)
        } else {
            assert(decl.entities.count == decl.initExprs.count)

            for (entity, value) in zip(decl.entities, decl.initExprs) {

                if entity.name == "_" {
                    continue // do nothing.
                }

                let entityType = entity.type!
                let irType = entityType.canonicalized()

                let irValue = emitStmt(value)

                let irValuePtr: IRValue
                if let function = context.currentProcedure?.llvm {
                    irValuePtr = emitEntryBlockAlloca(in: function, type: irType, named: entity.name, default: irValue)
                } else {
                    irValuePtr = emitGlobal(name: entity.mangledName!, type: irType, value: irValue)
                }

                llvmPointers[entity] = irValuePtr
            }
        }
        return VoidType().null()
    }

    @discardableResult
    func emitStmtAssignment(_ node: AstNode) -> IRValue {
        guard case .stmtAssign(let op, let lhs, let rhs, _) = node else {
            panic(node)
        }

        let entities = lhs.map {
            lookupEntity($0)!
        }

        if lhs.count > 1, rhs.count == 1, let value = rhs.first {

            let procRetType = checker.info.types[value]!

            assert(procRetType.isTuple)

            let procRetValue = emitStmt(value)
            let retValue = builder.buildAlloca(type: procRetValue.type)
            builder.buildStore(procRetValue, to: retValue)

            for (index, entity) in entities.enumerated() {
                if entity.name == "_" { continue }

                let rhsIrValuePtr = builder.buildStructGEP(retValue, index: index)

                let rhsIrValue: IRValue
                if case .exprUnary(.asterix, _, _) = lhs[index] {
                    // TODO(vdka): We need an actual solution for dealing with indirection. This will fail for multiple derefs
                    rhsIrValue = rhsIrValuePtr
                } else {
                    rhsIrValue = builder.buildLoad(rhsIrValuePtr)
                }

                let lhsIrValuePtr = llvmPointers[entity]!
                builder.buildStore(rhsIrValue, to: lhsIrValuePtr)
            }

            return VoidType().null()
        } else if entities.count == 1, let entity = entities.first,
            case .proc = entity.type!.kind, let value = rhs.first {

            //
            // Assign a value to a procedure. First class procedures, yay.
            //

            return emitProcedureDefinition(entity, value)
        } else if entities.count == 1 && rhs.count == 1,
            let entity = entities.first,
            let lval = lhs.first, let rval = rhs.first {

            let lvalueLocation: IRValue

            switch lval {
            case .ident, .exprSelector:
                lvalueLocation = llvmPointers[entity]!

            case .exprUnary(.asterix, let expr, _):
                lvalueLocation = emitStmt(expr)

            default:
                unimplemented()
            }

            let rvalue = emitStmt(rval)

            if case .equals = op {
                return builder.buildStore(rvalue, to: lvalueLocation)
            }

            let lvalue = builder.buildLoad(lvalueLocation)

            switch op {
            case .equals:
                fatalError()

            case .addEquals:
                let r = builder.buildAdd(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case .subEquals:
                let r = builder.buildSub(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case .mulEquals:
                let r = builder.buildMul(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case .divEquals:
                let r = builder.buildDiv(lvalue, rvalue, signed: !entity.type!.isUnsigned)

                return builder.buildStore(r, to: lvalueLocation)

            case .modEquals:
                let r = builder.buildRem(lvalue, rvalue, signed: !entity.type!.isUnsigned)

                return builder.buildStore(r, to: lvalueLocation)

            case .rshiftEquals: // FIXME(vdka): Arithmatic shift?
                let r = builder.buildShr(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case .lshiftEquals:
                let r = builder.buildShl(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case .andEquals:
                let r = builder.buildAnd(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)
                
            case .orEquals:
                let r = builder.buildOr(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)
                
            case .xorEquals:
                let r = builder.buildXor(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)
            }
        } else {
            assert(entities.count == rhs.count)

            for (index, entity) in entities.enumerated() {

                if entity.name == "_" {
                    continue // do nothing.
                }

                let lval = lhs[index]
                let rval = rhs[index]

                let lvalueLocation: IRValue
                switch lval {
                case .ident, .exprSelector:
                    lvalueLocation = llvmPointers[entity]!

                case .exprUnary(.asterix, let expr, _):
                    lvalueLocation = emitStmt(expr)

                default:
                    unimplemented()
                }

                let irValue = emitStmt(rval)

                builder.buildStore(irValue, to: lvalueLocation)
            }
        }

        return VoidType().null()
    }

    @discardableResult
    func emitStmtDefer(_ node: AstNode) -> IRValue {

        guard case .stmtDefer(let stmt, _) = node else {
            fatalError()
        }

        let curBlock = builder.insertBlock!
        let returnBlock = context.currentProcedure!.returnBlock

        let curFunction = builder.currentFunction!

        if context.currentProcedure!.deferBlock == nil {
            context.currentProcedure!.deferBlock = curFunction.appendBasicBlock(named: "defer")
            builder.positionAtEnd(of: context.currentProcedure!.deferBlock!)
            builder.buildBr(returnBlock)
        }

        let deferBlock  = context.currentProcedure!.deferBlock!

        if let firstInst = deferBlock.firstInstruction {
            //
            // By positioning before the first Instruction we ensure the things defered last execute first
            //
            builder.positionBefore(firstInst)
        }

        // At scope exit, reset the builder position
        defer { builder.positionAtEnd(of: curBlock) }

        emitStmt(stmt)

        return VoidType().null()
    }

    @discardableResult
    func emitStmtFor(_ node: AstNode) -> IRValue {
        guard case .stmtFor(let initializer, let cond, let post, let body, _) = node else {
            panic()
        }

        pushScope(for: body)
        defer { popScope() }

        let curFunction = builder.currentFunction!

        // Set these later to ensure correct order. (as a viewer)
        var loopBody: BasicBlock
        var loopDone: BasicBlock

        var loopCond: BasicBlock?
        var loopPost: BasicBlock?

        if let initializer = initializer {
            emitStmt(initializer)
        }

        if let cond = cond {

            loopCond = curFunction.appendBasicBlock(named: "for.cond")
            if post != nil {
                loopPost = curFunction.appendBasicBlock(named: "for.post")
            }
            loopBody = curFunction.appendBasicBlock(named: "for.body")
            loopDone = curFunction.appendBasicBlock(named: "for.done")

            builder.buildBr(loopCond!)

            builder.positionAtEnd(of: loopCond!)

            let condVal = emitExprConditional(for: cond)

            builder.buildCondBr(condition: condVal, then: loopBody, else: loopDone)
        } else {
            if post != nil {
                loopPost = curFunction.appendBasicBlock(named: "for.post")
            }
            loopBody = curFunction.appendBasicBlock(named: "for.body")
            loopDone = curFunction.appendBasicBlock(named: "for.done")

            builder.buildBr(loopBody)
        }

        context.escapePoints = Context.EscapePoints(break: loopDone, continue: loopPost ?? loopCond ?? loopBody)

        builder.positionAtEnd(of: loopBody)

        guard case .stmtBlock(let stmts, _) = body else {
            panic()
        }
        for stmt in stmts {
            emitStmt(stmt)
        }

        let hasJump = builder.insertBlock?.lastInstruction?.isATerminatorInst ?? false

        if let post = post {

            if !hasJump {
                builder.buildBr(loopPost!)
            }
            builder.positionAtEnd(of: loopPost!)

            emitStmt(post)

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

        builder.positionAtEnd(of: loopDone)

        return loopDone
    }

    func emitStmtReturn(_ node: AstNode) -> IRValue {
        guard let currentProcedure = context.currentProcedure else {
            fatalError("Return statement outside of procedure")
        }

        guard case .stmtReturn(let values, _) = node else {
            panic()
        }

        if values.count == 1, let value = values.first {
            let irValue = emitStmt(value)

            if !(irValue is VoidType) {
                builder.buildStore(irValue, to: currentProcedure.returnValue!)
            }
        }
        if values.count > 1 {
            var retVal = builder.buildLoad(currentProcedure.returnValue!)
            for (index, value) in values.enumerated() {
                let irValue = emitStmt(value)
                retVal = builder
                    .buildInsertValue(aggregate: retVal, element: irValue, index: index)
            }

            builder.buildStore(retVal, to: currentProcedure.returnValue!)
        }

        if let deferBlock = currentProcedure.deferBlock {
            builder.buildBr(deferBlock)
        } else {
            builder.buildBr(currentProcedure.returnBlock)
        }
        return VoidType().null()
    }

    func emitEntryBlockAlloca(in function: Function, type: IRType, named name: String, default defaultValue: IRValue? = nil) -> IRValue {

        let prevBlock = builder.insertBlock!

        let entryBlock = function.entryBlock!

        if let first = entryBlock.firstInstruction {
            builder.position(first, block: entryBlock)
        }

        let allocation = builder.buildAlloca(type: type, name: name)

        // return to the prev location
        builder.positionAtEnd(of: prevBlock)

        if let defaultValue = defaultValue {
            builder.buildStore(defaultValue, to: allocation)
        }

        return allocation
    }

    func emitProcedurePrototype(_ entity: Entity) -> Function {
        if let function = module.function(named: entity.mangledName!) {
            return function
        }

        let procIrType = entity.type!.canonicalized() as! FunctionType

        let procedure = builder.addFunction(entity.mangledName!, type: procIrType)

        guard case .proc(let params, _, _) = entity.type!.kind else {
            panic()
        }

        for (var paramIr, param) in zip(procedure.parameters, params) {

            if param.name != "_" {
                paramIr.name = param.name
            }
        }

        return procedure
    }

    @discardableResult
    func emitProcedureDefinition(_ entity: Entity, _ node: AstNode) -> Function {

        if let llvmPointer = llvmPointers[entity] {
            return llvmPointer as! Function
        }

        guard case let .litProc(_, body, _) = node else {
            preconditionFailure()
        }

        let prevBlock = builder.insertBlock
        defer {
            if let prevBlock = prevBlock {
                builder.positionAtEnd(of: prevBlock)
            }
        }

        // TODO(Brett): use mangled name when available
        var name = entity.mangledName!
        if case .directive("foreign", let args, _) = body, case .litString(let symbolName, _)? = args[safe: 1] {
            name = symbolName
        }

        let proc = emitProcedurePrototype(entity)

        llvmPointers[entity] = proc

        if case .directive("foreign", _, _) = body {
            return proc
        }

        let scope = entity.childScope!
        let previousScope = context.scope
        context.scope = scope
        defer {
            context.scope = previousScope
        }

        let entryBlock = proc.appendBasicBlock(named: "entry")
        let returnBlock = proc.appendBasicBlock(named: "return")

        let type = checker.info.types[node]!
        let irType = type.canonicalized() as! FunctionType

        guard case .proc(let params, let results, _) = type.kind else {
            panic()
        }

        var resultValue: IRValue? = nil

        builder.positionAtEnd(of: entryBlock)

        if !(irType.returnType is VoidType) {

            resultValue = emitEntryBlockAlloca(in: proc, type: irType.returnType, named: "result")
        }

        var args: [IRValue] = []
        for (i, param) in params.enumerated() {

            // TODO(Brett): values

            let arg = proc.parameter(at: i)!
            let argPointer = emitEntryBlockAlloca(in: proc, type: arg.type, named: entity.name)

            builder.buildStore(arg, to: argPointer)

            llvmPointers[param] = argPointer
            args.append(argPointer)
        }

        let procedure = Procedure(scope: scope, llvm: proc, type: irType, returnBlock: returnBlock, returnValue: resultValue)

        let previousProcPointer = context.currentProcedure
        context.currentProcedure = procedure
        defer {
            context.currentProcedure = previousProcPointer
        }

        guard case .stmtBlock(let stmts, _) = body else {
            panic()
        }
        for stmt in stmts {
            emitStmt(stmt)
        }

        let insert = builder.insertBlock!
        if !insert.hasTerminatingInstruction {
            if let deferBlock = procedure.deferBlock {
                builder.buildBr(deferBlock)
            } else {
                builder.buildBr(returnBlock)
            }
        }

        returnBlock.moveAfter(proc.lastBlock!)
        builder.positionAtEnd(of: returnBlock)

        if irType.returnType is VoidType {
            builder.buildRetVoid()
        } else {
            let result = builder.buildLoad(resultValue!, name: "result")
            builder.buildRet(result)
        }

        return proc
    }

    @discardableResult
    func emitExprCall(_ node: AstNode) -> IRValue {

        // TODO(vdka): We can have receivers that could be called that are not identifiers ie:
        /*
         foo : [] (void) -> void = [(void) -> void { print("hello") }]
         foo[0]()
         */

        guard
            case .exprCall(let receiver, let args, _) = node,
            case .ident(let ident, _) = receiver
            else {
                preconditionFailure()
        }

        let receiverEntity = context.scope.lookup(ident)!

        let function = llvmPointers[receiverEntity] as! Function
        //let function = module.function(named: ident)!

        let llvmArgs = args.map { emitStmt($0) }

        return builder.buildCall(function, args: llvmArgs)
    }

    // TODO(vdka): Check the types to determine llvm calls
    func emitExprOperator(_ node: AstNode) -> IRValue {

        switch node {
        case .exprUnary(let op, let expr, _):
            let type = checker.info.types[expr]!

            // TODO(vdka): There is much more to build.
            switch op {
            case .plus: // This is oddly a do nothing kind of operator. Lazy guy.
                return emitStmt(expr)

            case .minus:
                let val = emitStmt(expr)
                return builder.buildNeg(val)

            case .bang:
                let val = emitStmt(expr)
                if type === Type.bool {
                    return builder.buildNot(val)
                } else {
                    let truncdVal = builder.buildTrunc(val, type: IntType.int1)
                    return builder.buildNot(truncdVal)
                }

            case .tilde:
                let val = emitStmt(expr)
                return builder.buildNot(val)

            case .ampersand:
                switch expr {
                case .ident(let name, _):
                    let entity = context.scope.lookup(name)!
                    return llvmPointers[entity]!

                default:
                    return emitStmt(expr)
                }

            case .asterix:
                let val = emitStmt(expr)
                return builder.buildLoad(val)

            default:
                unimplemented("Unary Operator '\(op)'")
            }

        case .exprBinary(let op, let lhs, let rhs, _):

            var lvalue = emitStmt(lhs)
            var rvalue = emitStmt(rhs)

            let lhsType = checker.info.types[lhs]!
            let rhsType = checker.info.types[rhs]!

            // TODO(vdka): Trunc or Ext if needed / possible

            if lhsType !== rhsType {
                if lhsType.width == rhsType.width {
                    //
                    // `x: uint = 1; y: int = 1; z := x + y`
                    // We don't know what the return type should be so it's an error caught in the checker
                    //
                    panic()
                }
                if lhsType.isUnconstrained && !lhs.isBasicLit {
                    if lhsType.isUnsigned {
                        lvalue = builder.buildZExt(lvalue, type: rvalue.type)
                    } else {
                        lvalue = builder.buildSExt(lvalue, type: rvalue.type)
                    }
                }
                if rhsType.isUnconstrained && !rhs.isBasicLit {
                    if rhsType.isUnsigned {
                        rvalue = builder.buildZExt(rvalue, type: lvalue.type)
                    } else {
                        rvalue = builder.buildSExt(rvalue, type: lvalue.type)
                    }
                }
            }

            switch op {
            case .plus:
                return builder.buildAdd(lvalue, rvalue)

            case .minus:
                return builder.buildSub(lvalue, rvalue)

            case .asterix:
                return builder.buildMul(lvalue, rvalue)

            case .slash:
                if lhsType.isUnsigned {

                    return builder.buildDiv(lvalue, rvalue, signed: false)
                } else {

                    return builder.buildDiv(lvalue, rvalue, signed: true)
                }

            case .percent:
                if lhsType.isUnsigned {

                    return builder.buildRem(lvalue, rvalue, signed: false)
                } else {

                    return builder.buildRem(lvalue, rvalue, signed: true)
                }

            // TODO(vdka): Are these arithmatic or logical? Which should they be?
            case .doubleLeftChevron:
                return builder.buildShl(lvalue, rvalue)

            case .doubleRightChevron:
                return builder.buildShr(lvalue, rvalue)

            case .leftChevron:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedLessThan)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedLessThan)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedLessThan)
                }
                panic()

            case .leftChevronEquals:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedLessThanOrEqual)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedLessThanOrEqual)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedLessThanOrEqual)
                }
                panic()

            case .rightChevron:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThan)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedGreaterThan)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedGreaterThan)
                }
                panic()

            case .rightChevronEquals:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThanOrEqual)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedGreaterThanOrEqual)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedGreaterThanOrEqual)
                }
                panic()

            case .equalsEquals:
                if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .equal)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedEqual)
                }
                panic()

            case .bangEquals:
                if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .notEqual)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedNotEqual)
                }
                return builder.buildICmp(lvalue, rvalue, .notEqual)

            case .ampersand:
                return builder.buildAnd(lvalue, rvalue)

            case .pipe:
                return builder.buildOr(lvalue, rvalue)

            case .carot:
                return builder.buildXor(lvalue, rvalue)

            case .doubleAmpersand:
                let r = builder.buildAnd(lvalue, rvalue)
                return builder.buildTrunc(r, type: IntType.int1)

            case .doublePipe:
                let r = builder.buildOr(lvalue, rvalue)
                return builder.buildTrunc(r, type: IntType.int1)

            default:
                unimplemented("Binary Operator '\(op)'")
            }

        default:
            fatalError()
        }
    }

    func emitExprSubscript(_ node: AstNode, isLValue: Bool) -> IRValue {
        guard case .exprSubscript(let receiver, let value, _) = node else {
            preconditionFailure()
        }

        let lvalue: IRValue
        
        switch receiver {
        case .ident(let identifier, _):
            let entity = context.scope.lookup(identifier)!
            lvalue = llvmPointers[entity]!
            
        default:
            unimplemented()
        }
        
        let index = emitStmt(value)
        
        let ptr = builder.buildGEP(lvalue, indices: [
            IntType.int64.constant(0),
            index
            ])
        
        // set
        if isLValue {
            return ptr
        }
        
        //get
        return builder.buildLoad(ptr)
    }

    /// If a value is meant to be used as a condition use this.
    /// It will truncate to an `i1` for you
    func emitExprConditional(for node: AstNode) -> IRValue {
        let val = emitStmt(node)

        guard (val.type as! IntType).width == 1 else {
            return builder.buildTrunc(val, type: IntType.int1)
        }

        return val
    }
}


// MARK: Helper Code Gen

extension IRGenerator {

    func emitGlobalString(name: String? = nil, value: String) -> IRValue {
        return builder.buildGlobalStringPtr(
            value.escaped,
            name: name ?? ""
        )
    }

    func emitGlobal(name: String? = nil, type: IRType? = nil, value: IRValue? = nil) -> IRValue {
        let name = name ?? ""

        if let value = value {
            return builder.addGlobal(name, initializer: value)
        } else if let type = type {
            return builder.addGlobal(name, type: type)
        } else {
            preconditionFailure()
        }
    }
}


// MARK: Helpers

extension IRGenerator {

    func lookupEntity(_ node: AstNode) -> Entity? {

        switch node {
        case .ident(let ident, _):
            return context.scope.lookup(ident)

        case .exprSelector(let receiver, member: let member, _):
            guard let receiverScope = lookupEntity(receiver)?.childScope else {
                return nil
            }
            let prevScope = context.scope
            defer { context.scope = prevScope }
            context.scope = receiverScope
            return lookupEntity(member)

        case .exprUnary(.asterix, let expr, _):
            return lookupEntity(expr)

        case .exprUnary(.ampersand, let expr, _):
            return lookupEntity(expr)

        default:
            return nil
        }
    }

    @discardableResult
    func pushScope(for node: AstNode) -> Scope {
        let scope = checker.info.scopes[node]!

        context.scope = scope
        return scope
    }

    func popScope() {
        context.scope = context.scope.parent!
    }
}

extension String {

    //TODO(vdka): This should be done in the lexer.
    var escaped: String {
        return self.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}

extension BasicBlock {
    var hasTerminatingInstruction: Bool {
        guard let instruction = lastInstruction else {
            return false
        }
        
        return instruction.isATerminatorInst
    }
}
