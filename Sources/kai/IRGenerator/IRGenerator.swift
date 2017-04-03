import LLVM

// TODO(vdka): IRGenerator _should_ possibly take in a file
//  This would mean that the initial context would be file scope. Not universal scope.
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
    
    enum Error: Swift.Error {
        case unimplemented(String)
        case invalidSyntax
        case invalidOperator(String)
        case unidentifiedSymbol(String)
        case preconditionNotMet(expected: String, got: String)
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
            case .declValue:
                emitDeclaration(for: node)

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
    func emitLiteral(for node: AstNode) -> IRValue {
        switch node {
        case .litInteger(let val, _):
            let type = checker.info.types[node]!
            return (type.canonicalized() as! IntType).constant(val)

        case .litFloat(let val, _):
            let type = checker.info.types[node]!
            return (type.canonicalized() as! FloatType).constant(val)

        case .litString(let val, _):
            return builder.buildGlobalStringPtr(val.escaped)

        case .litCompound(let elements, _):
            let type = checker.info.types[node]!

            if case .array(let underlyingType, _) = type.kind {
                let values = elements.map {
                    emitStmt(for: $0)
                }
                // FIXME(vdka): For literals that do not exactly match the count of the array they are assigned to this emits bad IR.
                return ArrayType.constant(values, type: underlyingType.canonicalized())
            }

            unimplemented("Emitting constants for \(type)")

        default:
            fatalError()
        }
    }

    @discardableResult
    func emitStmt(for node: AstNode, isLValue: Bool = false) -> IRValue {
        switch node {
        case .litString, .litFloat, .litInteger, .litProc, .litCompound:
            return emitLiteral(for: node)

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
            return emitDeclaration(for: node)
            
        case .stmtDefer:
            return emitDeferStmt(for: node)

        case .exprUnary:
            return emitOperator(for: node)

        case .exprBinary:
            return emitOperator(for: node)

        case .exprSubscript:
            return emitSubscript(for: node, isLValue: isLValue)
            
        case .exprCall(_, let args, _):
            if checker.info.casts.contains(node) {
                return emitStmt(for: args.first!)
            }
            return emitProcedureCall(for: node)

        case .exprParen(let expr, _):
            return emitStmt(for: expr)

        case .stmtExpr(let expr):
            return emitStmt(for: expr)

        case .stmtAssign:
            return emitAssignment(for: node)

        case .stmtBlock(let stmts, _):
            pushScope(for: node)
            defer { popScope() }

            for stmt in stmts {
                emitStmt(for: stmt)
            }
            return VoidType().null()
            
        case .stmtReturn:
            return emitReturnStmt(for: node)

        case .stmtIf:
            return emitIfStmt(for: node)

        case .stmtFor:
            return emitForStmt(for: node)

        case .stmtBreak:
            return builder.buildBr(context.escapePoints!.break as! BasicBlock)

        case .stmtContinue:
            return builder.buildBr(context.escapePoints!.continue as! BasicBlock)
            
        default:
            fatalError()
        }
    }

    func emitIfStmt(for node: AstNode) -> IRValue {
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

        let condVal = emitConditional(for: cond)

        builder.buildCondBr(condition: condVal, then: thenBlock, else: elseBlock ?? postBlock)

        //
        // Emit the `then` block
        //

        builder.positionAtEnd(of: thenBlock)

        emitStmt(for: thenStmt)

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

            emitStmt(for: elseStmt)

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
    func emitDeclaration(for node: AstNode) -> IRValue {

        // TODO(vdka): isRuntime? Is that in emission or just checking?
        guard case .declValue(_, let names, _, let values, _) = node else {
            panic(node)
        }

        let decl = checker.info.decls[node]!

        /// This should be a proc call.
        if names.count > 1, values.count == 1, let value = values.first {

            let procRetType = checker.info.types[value]!

            assert(procRetType.isTuple)

            let procRetValue = emitStmt(for: value)
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

                let irValue = emitStmt(for: value)

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
    func emitAssignment(for node: AstNode) -> IRValue {
        guard case .stmtAssign(let op, let lhs, let rhs, _) = node else {
            panic(node)
        }

        let entities = lhs.map {
            lookupEntity($0)!
        }

        if lhs.count > 1, rhs.count == 1, let value = rhs.first {

            let procRetType = checker.info.types[value]!

            assert(procRetType.isTuple)

            let procRetValue = emitStmt(for: value)
            let retValue = builder.buildAlloca(type: procRetValue.type)
            builder.buildStore(procRetValue, to: retValue)

            for (index, entity) in entities.enumerated() {
                if entity.name == "_" { continue }
                let irType = entity.type!.canonicalized()

                let rhsIrValuePtr = builder.buildStructGEP(retValue, index: index)

                let rhsIrValue: IRValue
                if case .exprUnary("*", _, _) = lhs[index] {
                    rhsIrValue = rhsIrValuePtr
                } else {
                    rhsIrValue = builder.buildLoad(rhsIrValuePtr)
                }

                let lhsIrValuePtr = llvmPointers[entity]!
                builder.buildStore(rhsIrValue, to: lhsIrValuePtr)
                /*
                let lhsIrValue: IRValue
                if let function = context.currentProcedure?.llvm {
                    lhsIrValue = emitEntryBlockAlloca(in: function, type: irType, named: entity.name, default: rhsIrValue)
                } else {
                    lhsIrValue = emitGlobal(name: entity.name, type: irType, value: rhsIrValue)
                }

                llvmPointers[entity] = lhsIrValue
                 */
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

            case .exprUnary("*", let expr, _):
                lvalueLocation = emitStmt(for: expr)

            default:
                unimplemented()
            }

            let rvalue = emitStmt(for: rval)

            if op == "=" {
                return builder.buildStore(rvalue, to: lvalueLocation)
            }

            let lvalue = builder.buildLoad(lvalueLocation)

            switch op {
            case "+=":
                let r = builder.buildAdd(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case "-=":
                let r = builder.buildSub(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case "*=":
                let r = builder.buildMul(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case "/=":
                let r = builder.buildDiv(lvalue, rvalue, signed: !entity.type!.isUnsigned)

                return builder.buildStore(r, to: lvalueLocation)

            case "%=":
                let r = builder.buildRem(lvalue, rvalue, signed: !entity.type!.isUnsigned)

                return builder.buildStore(r, to: lvalueLocation)

            case ">>=": // FIXME(vdka): Arithmatic shift?
                let r = builder.buildShr(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case "<<=":
                let r = builder.buildShl(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)

            case "&=":
                let r = builder.buildAnd(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)
                
            case "|=":
                let r = builder.buildOr(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)
                
            case "^=":
                let r = builder.buildXor(lvalue, rvalue)
                return builder.buildStore(r, to: lvalueLocation)
                
            default:
                panic()
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

                case .exprUnary("*", let expr, _):
                    lvalueLocation = emitStmt(for: expr)

                default:
                    unimplemented()
                }

                let irValue = emitStmt(for: rval)

                builder.buildStore(irValue, to: lvalueLocation)
            }
        }

        return VoidType().null()
    }

    @discardableResult
    func emitProcedureCall(for node: AstNode) -> IRValue {

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

        let llvmArgs = args.map { emitStmt(for: $0) }
        
        return builder.buildCall(function, args: llvmArgs)
    }

    @discardableResult
    func emitForStmt(for node: AstNode) -> IRValue {
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
            emitStmt(for: initializer)
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

            let condVal = emitConditional(for: cond)

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
            emitStmt(for: stmt)
        }

        let hasJump = builder.insertBlock?.lastInstruction?.isATerminatorInst ?? false

        if let post = post {

            if !hasJump {
                builder.buildBr(loopPost!)
            }
            builder.positionAtEnd(of: loopPost!)

            emitStmt(for: post)

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

    /// If a value is meant to be used as a condition use this.
    /// It will truncate to an `i1` for you
    func emitConditional(for node: AstNode) -> IRValue {
        let val = emitStmt(for: node)

        guard (val.type as! IntType).width == 1 else {
            return builder.buildTrunc(val, type: IntType.int1)
        }

        return val
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

        case .exprUnary("*", let expr, _):
            return lookupEntity(expr)

        case .exprUnary("&", let expr, _):
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

extension BasicBlock {
    var hasTerminatingInstruction: Bool {
        guard let instruction = lastInstruction else {
            return false
        }
        
        return instruction.isATerminatorInst
    }
}
