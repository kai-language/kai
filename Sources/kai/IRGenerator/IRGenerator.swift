import LLVM

// TODO(vdka): IRGenerator _should_ possibly take in a file
//  This would mean that the initial context would be file scope. Not universal scope.
class IRGenerator {

    var file: ASTFile
    var context = Context()

    let module: Module
    let builder: IRBuilder
    let internalFuncs: InternalFuncs

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
    
    //FIXME(Brett):
    //TODO(Brett): will be removed when #foreign is supported
    struct InternalFuncs {
        var puts: Function?
        var printf: Function?
        
        init(builder: IRBuilder) {
            puts = generatePuts(builder: builder)
            printf = generatePrintf(builder: builder)
        }
        
        func generatePuts(builder: IRBuilder) -> Function {
            let putsType = FunctionType(
                argTypes:[ PointerType(pointee: IntType.int8) ],
                returnType: IntType.int32
            )
            
            return builder.addFunction("puts", type: putsType)
        }
        
        func generatePrintf(builder: IRBuilder) -> Function {
            let printfType = FunctionType(
                argTypes: [PointerType(pointee:IntType.int8)],
                returnType: IntType.int32,
                isVarArg: true
            )
            return builder.addFunction("printf", type: printfType)
        }
    }
    
    enum Error: Swift.Error {
        case unimplemented(String)
        case invalidSyntax
        case invalidOperator(String)
        case unidentifiedSymbol(String)
        case preconditionNotMet(expected: String, got: String)
    }
    
    init(_ file: ASTFile) throws {
        self.file = file
        module = Module(name: file.name)
        builder = IRBuilder(module: module)
        internalFuncs = InternalFuncs(builder: builder)
    }
    
    static func build(for file: ASTFile) throws -> Module {
        let generator = try IRGenerator(file)
        try generator.emitGlobals()
        try generator.emitMain()
        
        return generator.module
    }
}

extension IRGenerator {

    func emitMain() throws {

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
    }
    
    func emitGlobals() throws {
        for node in file.nodes {
            // TODO(vdka): Emit more than just procDecls

            switch node {
            case .decl(let decl):
                switch decl {
                case .value(_, _, let type, _, _):

                    switch type {
                    case .type(.proc)?:
                        try emitProcedureDefinition(node)

                    default:
                        break
                    }
                default:
                    break
                }
            default:
                break
            }
        }
    }
}

extension IRGenerator {

    @discardableResult
    func emitLiteral(for node: AstNode) -> IRValue {

        switch node {
        case .literal(let lit):
            switch lit {
            case .basic(let b, _):
                return emitBasicLiteral(for: b)

            case .compound, .proc:
                fatalError()
            }

        default:
            fatalError()
        }
    }

    @discardableResult
    func emitBasicLiteral(for literal: AstNode.Literal.Basic) -> IRValue {

        switch literal {
        case .integer(let i):
            return IntType(width: 64).constant(i)

        case .float(let f):
            return FloatType.double.constant(f)

        case .string(let s):
            return builder.buildGlobalStringPtr(s.escaped)
        }
    }

    func emitStmt(for node: AstNode) -> IRValue {
        switch node {
        case .invalid:
            break

        case .ident:
            break

        case .basicDirective:
            break

        case .ellipsis:
            break

        case .argument:
            break

        case .field:
            break

        case .fieldList:
            break

        case .literal:
            return emitLiteral(for: node)

        case let .expr(expr):
            switch expr {
            case .bad:
                fatalError("Bad expr in IR Generator \(node)")

            case .unary,
                 .binary:
                return emitOperator(for: node)

            case .paren(expr: let expr, _):
                return emitStmt(for: expr)

            case .selector:
                unimplemented("IR for member reference")

            case .subscript:
                unimplemented("IR for subscripts")

            case .deref:
                unimplemented("IR for Pointer Dereference")

            case .call:
                return emitProcedureCall(for: node)

            case .ternary:
                unimplemented("IR for Ternary")
            }

        case .stmt(let stmt):
            switch stmt {
            case .bad:
                fatalError("Bad stmt in IR Generator \(node)")

            case .empty:
                break

            case .expr(let child):
                return emitStmt(for: child)

            case .assign:
                return emitAssignment(for: node)

            case .block:
                unimplemented("IR For Blocks")

            case .if:
                break

            case .return:
                break

            case .for:
                break

            case .case:
                break

            case .defer:
                return emitDeferStmt(for: node)

            case .control:
                break
            }

        case .decl(let decl):
            switch decl {
            case .bad:
                break

            case .value:
                break

            case .import:
                break

            case .library:
                break
            }

        case .type(let type):
            switch type {
            case .helper:
                break

            case .proc:
                break

            case .pointer:
                break
                
            case .array:
                break
                
            case .dynArray:
                break
                
            case .struct:
                break
                
            case .enum:
                break
            }
        }

        return VoidType().null()
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
    func emitDeclaration(for node: AstNode) throws -> IRValue? {
        unimplemented()
        /*
>>>>>>> round2
        guard
            case .declaration(let symbol) = node.kind,
            let type = symbol.type
        else {
            throw Error.preconditionNotMet(expected: "declaration", got: "\(node)")
        }
        
        // what should we do here about forward declarations of foreign variables?
        var defaultValue: IRValue? = nil
        
        if let valueChild = node.children.first {
            defaultValue = try emitExpression(for: valueChild)
        }
        
        let typeCanonicalized = try type.canonicalized()

        let llvm = emitEntryBlockAlloca(
            in: currentProcedure!.pointer,
            type: typeCanonicalized,
            named: symbol.name.string,
            default: defaultValue
        )
        
        symbol.llvm = llvm
        
        return llvm
        */
    }

    @discardableResult
    func emitAssignment(for node: AstNode) -> IRValue {
        guard case .stmt(.assign(op: let op, lhs: let lhs, rhs: let rhs, _)) = node else {
            preconditionFailure()
        }
        unimplemented("Complex Assignment", if: op != "=")
        unimplemented("Multiple Assignment", if: lhs.count != 1 || rhs.count != 1)

        // TODO(vdka): Other lvalues can be valid too:
        // subscript, selectors ..
        guard case .ident(let ident, _) = lhs[0] else {
            fatalError("Unexpected lvalue kind")
        }

        let lvalueEntity = context.scope.lookup(ident)!
        let rvalue = emitStmt(for: rhs[0])

        return builder.buildStore(rvalue, to: lvalueEntity.llvm!)
    }

    @discardableResult
    func emitProcedureCall(for node: AstNode) -> IRValue {

        // TODO(vdka): We can have receivers that could be called that are not identifiers ie:
        /*
         foo : [] (void) -> void = [(void) -> void { print("hello") }]
         foo[0]()
        */
        guard
            case .expr(.call(receiver: let receiver, args: let args, _)) = node,
            case .ident(let ident, _) = receiver
        else {
            preconditionFailure()
        }

        // FIXME(Brett):
        // TODO(Brett): will be removed when #foreign is supported
        if ident == "print" {
            return emitPrintCall(for: args)
        }
        
        // FIXME(Brett): why is this lookup failing?
        /*guard let symbol = SymbolTable.current.lookup(identifier) else {
            return
        }
        guard let function = symbol.pointer else {
            unimplemented("lazy-generation of procedures")
        }*/
        
        let function = module.function(named: ident)!

        let llvmArgs = args.map(emitStmt)
        
        return builder.buildCall(function, args: llvmArgs)
    }
    
    // FIXME(Brett):
    // TODO(Brett): will be removed when #foreign is supported
    func emitPrintCall(for args: [AstNode]) -> IRValue {
        unimplemented("Variadic print", if: args.count != 1)

        let string = emitStmt(for: args[0])
        return builder.buildCall(internalFuncs.puts!, args: [string])
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
