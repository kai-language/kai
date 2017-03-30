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

        var currentProcedure: ProcedurePointer?

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
        try generator.emitGlobals()
        try generator.emitMain()
        
        return generator.module
    }
}

extension IRGenerator {

    func emitMain() throws {
//        unimplemented("Finding and emitting 'main'")

        guard let _ = checker.main else {
            unimplemented("files without mains. Should be easy though...")
        }

//        let mainType = FunctionType(argTypes: [], returnType: VoidType())
//        let main = builder.addFunction("main", type: try mainEntity.canonicalized() as! FunctionType)
//        mainEntity.llvm = main
//        let entry = main.appendBasicBlock(named: "entry")
//        builder.positionAtEnd(of: entry)

        /*
        // TODO(Brett): Update to emit function definition
        let mainType = FunctionType(argTypes: [], returnType: VoidType())
        let main = builder.addFunction("main", type: mainType)
        let entry = main.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: entry)

        for child in file.nodes {

            switch child {
            case .expr(.call(_)):
                emitProcedureCall(for: child)

            default:
                break
            }

        }
        
        builder.buildRetVoid()
        */
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

        default:
            fatalError()
        }
    }

    @discardableResult
    func emitStmt(for node: AstNode) -> IRValue {
        switch node {
        case .litString, .litFloat, .litInteger, .litProc:
            return emitLiteral(for: node)

        // FIXME(vdka): Feels a bit hacky.
        case .ident("true", _):
            return IntType.int1.constant(1)

        case .ident("false", _):
            return IntType.int1.constant(0)

        case .ident(let identifier, _):
            let entity = context.scope.lookup(identifier)!
            return builder.buildLoad(llvmPointers[entity]!)

        case .exprSelector:
            unimplemented("Emitting selector expressions. Should be easy... ")
            /*
             #import "globals.kai"
             
             x := globals.tau + globals.pi
            */
        
        case .declValue:
            return emitDeclaration(for: node)
            
        case .stmtDefer:
            return emitDeferStmt(for: node)

        case .exprUnary:
            return emitOperator(for: node)

        case .exprBinary:
            return emitOperator(for: node)

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
        guard case let .declValue(_, names, _, values, _) = node else {
            preconditionFailure()
        }
        
        // TODO(Brett): multiple declarations
        let name = names[0]
        let value = values.first
        
        // FIXME(Brett): use scope lookup when scope traversal setup
        let entity = checker.info.definitions[name]!
        let type = entity.type!

        switch type.kind {
        case .proc:
            return emitProcedureDefinition(name, value!)
            
        default:
            break
        }
        
        let canonicalizedType = type.canonicalized()
        
        let defaultValue: IRValue?
        if let value = value {
            defaultValue = emitStmt(for: value)
        } else {
            defaultValue = nil
        }
        
        let pointer: IRValue
        if let currentProcedure = context.currentProcedure?.pointer {
            pointer = emitEntryBlockAlloca(
                in: currentProcedure,
                type: canonicalizedType,
                named: name.identifier,
                default: defaultValue
            )
        } else {
            pointer = emitGlobal(name: name.identifier, type: canonicalizedType, value: defaultValue)
        }
        
        llvmPointers[entity] = pointer
        
        return pointer
    }

    @discardableResult
    func emitAssignment(for node: AstNode) -> IRValue {
        guard case .stmtAssign(let op, let lhs, let rhs, _) = node else {
            preconditionFailure()
        }
        unimplemented("Complex Assignment", if: op != "=")
        unimplemented("Multiple Assignment", if: lhs.count != 1 || rhs.count != 1)

        guard case .ident(let ident, _) = lhs[0] else {
            unimplemented("Non ident lvalue in assignment")
        }

        let lvalueEntity = context.scope.lookup(ident)!
        let rvalue = emitStmt(for: rhs[0])

        return builder.buildStore(rvalue, to: llvmPointers[lvalueEntity]!)
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

        let llvmArgs = args.map(emitStmt)
        
        return builder.buildCall(function, args: llvmArgs)
    }

    @discardableResult
    func emitForStmt(for node: AstNode) -> IRValue {
        guard case .stmtFor(let initializer, let cond, let post, let body, _) = node else {
            panic()
        }

        let prevContext = context
        defer { context = prevContext }
        context.scope = checker.info.scopes[node]!

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

        emitStmt(for: body)

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

extension IRGenerator {

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
