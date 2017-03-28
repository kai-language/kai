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

        var parent: Context? = nil

        var state: State = .global

        var scope: Scope = .universal

        enum State {
            case global

            case procedureBody
            case structureBody
            case enumerationBody

            // allow keywords break & continue
            case loopBody
            
            case procedureCall
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

        case .exprCall:
            return emitProcedureCall(for: node)

        case .exprParen(let expr, _):
            return emitStmt(for: expr)

        case .stmtExpr(let expr):
            return emitStmt(for: expr)

        case .stmtAssign:
            return emitAssignment(for: node)

        case .stmtBlock(let statements, _):
            statements.forEach {
                _ = emitStmt(for: $0)
            }
            return VoidType().null()
            
        case .stmtReturn:
            return emitReturnStmt(for: node)

        case .stmtFor:
            return emitForStmt(for: node)
            
        default:
            fatalError()
        }
    }

    #if false
    // NOTE(vdka): Because this emits both exprs and stmts it should be named emitStmt
    func emitExpression(for node: AstNode) throws -> IRValue {

        switch node.kind {
        //NOTE(Brett): how do we want to handle different values here, should we
        // continue to ignore them and just return nil?
        case .scope(_):
            for child in node.children {
                _ = try emitExpression(for: child)
            }
            return VoidType().null()
            
        case .assignment:
            return try emitAssignment(for: node)
            
        //case .declaration:
            //return try emitDeclaration(for: node)
            
        case .procedureCall:
            return try emitProcedureCall(for: node)
            
        case .conditional:
            return try emitConditional(for: node)
            
        case .defer:
            return try emitDeferStmt(for: node)
            
        case .operator(_):
            return try emitOperator(for: node)
            
        case .return:
            try emitReturn(for: node)
            return VoidType().null()
            
        case .integer(let valueString):
            //NOTE(Brett): should this throw?
            let value = Int(valueString.string) ?? 0
            return IntType.int64.constant(value)
            
        case .boolean(let boolean):
            return IntType.int1.constant(boolean ? 1 : 0)
            
        case .string(let string):
            return emitGlobalString(value: string)
            
        /*case .identifier(let identifier):
            guard let symbol = SymbolTable.current.lookup(identifier) else {
                fallthrough
            }
            
            return builder.buildLoad(symbol.pointer!)
          */
            
        default:
            unimplemented("unsupported kind: \(node.kind)")
        }
    }
    #endif
    
    func emitConditional(for node: AstNode) -> IRValue {
        unimplemented()
        
        /*guard let function = currentProcedure?.pointer else {
            preconditionFailure("Not currently in a function")
        }
        
        guard case .conditional = node.kind, node.children.count >= 2 else {
            preconditionFailure("Expected conditional got: \(node.kind)")
        }
        
        let currentBlock = builder.insertBlock!
        let thenBody = function.appendBasicBlock(named: "then")
        let elseBody = function.appendBasicBlock(named: "else")
        let mergeBody = function.appendBasicBlock(named: "merge")
        
        builder.positionAtEnd(of: currentBlock)
        let conditional = try emitExpression(for: node.children[0])
        builder.buildCondBr(condition: conditional, then: thenBody, else: elseBody)
        
        builder.positionAtEnd(of: thenBody)
        guard case .scope(let thenScope) = node.children[1].kind else {
            preconditionFailure("Expected scope for `then` body.")
        }
        context?.scope = thenScope
        defer {
           // SymbolTable.pop()
        }
        
        _ = try emitExpression(for: node.children[1])
        
        if !thenBody.hasTerminatingInstruction {
            builder.buildBr(mergeBody)
        }
        
        if !builder.insertBlock!.hasTerminatingInstruction {
            builder.buildBr(mergeBody)
        }
        
        builder.positionAtEnd(of: elseBody)
        // has else body
        if node.children.count >= 3 {
            if case .scope(let elseScope) = node.children[2].kind {
                SymbolTable.current = thenScope
                defer {
                    //SymbolTable.pop()
                }
            }
            
            _ = try emitExpression(for: node.children[2])
            
            if !elseBody.hasTerminatingInstruction {
                builder.buildBr(mergeBody)
            }
            
            if !builder.insertBlock!.hasTerminatingInstruction {
                builder.buildBr(mergeBody)
            }
            
        } else {
            builder.buildBr(mergeBody)
        }
        
        builder.positionAtEnd(of: mergeBody)
        
        // NOTE(Brett): do we really want to return this?
        return conditional
         */
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

        if let initializer = initializer {
            emitStmt(for: initializer)
        }

        let loopBlock = curFunction.appendBasicBlock(named: "loopbody")

        builder.buildBr(loopBlock)

        builder.positionAtEnd(of: loopBlock)

        emitStmt(for: body)

        if let post = post {
            emitStmt(for: post)
        }

        let afterBlock = curFunction.appendBasicBlock(named: "afterloop")

        if let cond = cond {
            var condVal = emitStmt(for: cond)

            condVal = builder.buildTrunc(condVal, type: IntType.int1)

            builder.buildCondBr(condition: condVal, then: loopBlock, else: afterBlock)
        }

        builder.positionAtEnd(of: afterBlock)

        return loopBlock
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
