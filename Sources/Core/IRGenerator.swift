
import LLVM

// sourcery:noinit
struct IRGenerator {

    var package: SourcePackage
    var topLevelNodes: [TopLevelStmt]

    var testCases: [Function] = []

    /// - Note: Used for the generative features only (builtins & specializations)
    var specializations: [FunctionSpecialization] = []

    let isInvokationFile: Bool
    let isModuleDependency: Bool

    var context: Context

    var passManager: FunctionPassManager { return package.passManager }
    var module: Module { return package.module }
    var b: IRBuilder { return package.builder }

    init(topLevelNodes: [TopLevelStmt], package: SourcePackage, context: Context, isInvokationFile: Bool, isModuleDependency: Bool) {
        self.topLevelNodes = topLevelNodes
        self.package = package
        self.context = context
        self.isModuleDependency = isModuleDependency
        self.isInvokationFile = isInvokationFile
    }

    init(specializations: [FunctionSpecialization], package: SourcePackage) {
        self.topLevelNodes = []
        self.specializations = specializations
        self.package = package
        self.context = Context(mangledNamePrefix: "", deferBlocks: [], returnBlock: nil, previous: nil)
        self.isModuleDependency = true
        self.isInvokationFile = false
    }

    // sourcery:noinit
    class Context {
        var mangledNamePrefix: String
        var deferBlocks: [BasicBlock]
        var returnBlock: BasicBlock?
        var previous: Context?

        init(mangledNamePrefix: String, deferBlocks: [BasicBlock], returnBlock: BasicBlock?, previous: Context?) {
            self.mangledNamePrefix = mangledNamePrefix
            self.deferBlocks = deferBlocks
            self.returnBlock = returnBlock
            self.previous = previous
        }
    }

    mutating func pushContext(scopeName: String, returnBlock: BasicBlock? = nil) {
        context = Context(mangledNamePrefix: mangle(scopeName), deferBlocks: context.deferBlocks, returnBlock: returnBlock ?? context.returnBlock, previous: context)
    }

    mutating func popContext() {
        context = context.previous!
    }

    func mangle(_ name: String) -> String {
        return (context.mangledNamePrefix.isEmpty ? "" : context.mangledNamePrefix + ".") + name
    }

    func symbol(for entity: Entity) -> String {
        if let linkname = entity.linkname {
            return linkname
        }
        if let mangledName = entity.mangledName {
            return mangledName
        }
        let mangledName = (context.mangledNamePrefix.isEmpty ? "" : context.mangledNamePrefix + ".") + entity.name
        entity.mangledName = mangledName
        return mangledName
    }

    mutating func value(for entity: Entity) -> IRValue {
        if entity.isParameter {
            // parameters are always in the same package.
            return entity.value!
        } else if entity.isBuiltin {
            let builtin = builtinEntities.first(where: { $0.entity === entity })!
            return builtin.gen(&self)
        }
        guard let entityPackage = entity.package else {
            return entity.value!
        }

        let topLevelEntity = entity.owningScope.isPackage || entity.owningScope.isFile
        guard entityPackage === package || !topLevelEntity else {
            // The entity is not in the same package as us, this means it will be in a
            //   different `.o` file and we will want to emit a 'stub'
            let symbol = self.symbol(for: entity)

            // only constant functions are emitted as functions, otherwise they are actually globals
            if let type = entity.type as? ty.Function, entity.isConstant {
                return addOrReuseFunction(named: symbol, type: canonicalizeSignature(type))
            } else {
                if let existing = module.global(named: symbol) {
                    return existing
                }
                return b.addGlobal(symbol, type: canonicalize(entity.type!))
            }
        }

        if let constant = entity.constant {
            switch constant {
            case let c as UInt64:
                // FIXME: What is this....
                let type = LLVM.IntType(width: entity.type!.width!, in: module.context)
                let ptr = b.buildAlloca(type: type)
                _ = b.buildStore(type.constant(c), to: ptr)
                entity.value = ptr

            default:
                fatalError()
            }
        }

        if entity.value == nil {
            let prevContext = context
            assert(topLevelEntity, "Assumption is that entities without existing values are only possible at file or package scope")
            assert(entity.package === package)

            // Use the context for the file itself
            context = entity.file!.irContext
            emit(decl: entity.declaration!)
            context = prevContext
        }
        return entity.value!
    }

    func entryBlockAlloca(type: IRType, name: String = "", default def: IRValue? = nil) -> IRValue {
        let prev = b.insertBlock!
        let entry = b.currentFunction!.entryBlock!

        // TODO: Could probably get some better performance by doing something smarter
        if let endOfAlloca = entry.instructions.first(where: { !$0.isAAllocaInst }) {
            b.position(endOfAlloca, block: entry)
        } else {
            b.positionAtEnd(of: entry)
        }

        let alloc = b.buildAlloca(type: type, name: name)

        b.positionAtEnd(of: prev)

        if let def = def {
            b.buildStore(def, to: alloc)
        }

        return alloc
    }

    func addOrReuseFunction(named: String, type: FunctionType) -> Function {
        if let existing = module.function(named: named) {
            return existing
        }
        return b.addFunction(named, type: type)
    }

    func addOrReuseGlobal(named: String, type: IRType) -> Global {
        if let existing = module.global(named: named) {
            return existing
        }
        return b.addGlobal(named, type: type)
    }

    func addOrReuseGlobal(named: String, initializer: IRValue) -> Global {
        if let existing = module.global(named: named) {
            return existing
        }
        return b.addGlobal(named, initializer: initializer)
    }

    lazy var i1: IntType = {
        return IntType(width: 1, in: module.context)
    }()

    // Odd sizes
    lazy var i3: IntType = {
        return IntType(width: 3, in: module.context)
    }()

    lazy var i61: IntType = {
        return IntType(width: 61, in: module.context)
    }()

    lazy var i60: IntType = {
        return IntType(width: 60, in: module.context)
    }()

    lazy var i8: IntType = {
        return IntType(width: 8, in: module.context)
    }()

    lazy var i32: IntType = {
        return IntType(width: 32, in: module.context)
    }()

    lazy var i64: IntType = {
        return IntType(width: 64, in: module.context)
    }()

    lazy var f64: FloatType = {
        return FloatType(kind: .double, in: module.context)
    }()

    lazy var void: VoidType = {
        return VoidType(in: module.context)
    }()

    lazy var word: IntType = {
        return targetMachine.dataLayout.intPointerType(context: module.context)
    }()

    lazy var signalCallbackType: FunctionType = {
        return LLVM.FunctionType(argTypes: [i32], returnType: void)
    }()

    lazy var raise: Function = {
        let type = FunctionType(argTypes:[i32], returnType: void)
        return addOrReuseFunction(named: "raise", type: type)
    }()

    lazy var trap: Function = {
        let type = FunctionType(argTypes: [], returnType: void)
        return addOrReuseFunction(named: "llvm.trap", type: type)
    }()

    lazy var testResults = self.b.addGlobal("$testResults", initializer:
        LLVM.ArrayType(elementType: self.i1, count: self.testCases.count).null()
    )
    lazy var testAsserted = self.b.addGlobal("$testAsserted", initializer: self.i1.constant(0))

    lazy var printf = self.addOrReuseFunction(named: "printf", type: LLVM.FunctionType(argTypes: [LLVM.PointerType(pointee: i8)], returnType: i32, isVarArg: true))

    mutating func synthTestMain() {
        if let oldMain = module.function(named: "main") {
            oldMain.delete()
        }

        let main = b.addFunction("main", type: FunctionType(argTypes: [], returnType: VoidType(in: module.context)))
        let entryBlock = main.appendBasicBlock(named: "entry", in: module.context)
        let returnBlock = main.appendBasicBlock(named: "ret", in: module.context)

        b.positionAtEnd(of: returnBlock)
        b.buildRetVoid()

        b.positionAtEnd(of: entryBlock)

        for (index, test) in testCases.enumerated() {
            _ = b.buildCall(test, args: [])
            let result = b.buildGEP(testResults, indices: [0, i32.constant(index)])

            let failure = b.buildLoad(testAsserted)
            b.buildStore(failure, to: result)
            b.buildStore(i1.constant(0), to: testAsserted)
        }

        let successSymbol = b.buildGlobalStringPtr("✔".green)
        let failureSymbol = b.buildGlobalStringPtr("✘".red)

        let indiviualFormat = b.buildGlobalStringPtr("%s %s\n")

        var passes: IRValue = i64.constant(0)
        for (index, test) in testCases.enumerated() {
            let asserted = b.buildLoad(b.buildGEP(testResults, indices: [0, i32.constant(index)]))
            let sym = b.buildSelect(asserted, then: failureSymbol, else: successSymbol)
            let name = b.buildGlobalStringPtr(test.name)
            _ = b.buildCall(printf, args: [indiviualFormat, sym, name])
            passes = b.buildAdd(passes, b.buildSelect(asserted, then: 0, else: 1))
        }

        let percentPass = b.buildMul(b.buildDiv(b.buildIntToFP(passes, type: FloatType(kind: .double, in: module.context), signed: false), FloatType(kind: .double, in: module.context).constant(Double(testCases.count))), FloatType(kind: .double, in: module.context).constant(100))
        let summaryFormat = b.buildGlobalStringPtr("%.2f%% success (%ld out of %ld)\n")
        _ = b.buildCall(printf, args: [summaryFormat, percentPass, passes, i64.constant(testCases.count)])

        b.buildBr(returnBlock)
    }
}

extension IRGenerator {

    mutating func emit() {
        // NOTE: Mangle prefix is setup lazily in SourceFile
        //  This is done so that the prefix is established for order independence

        guard specializations.isEmpty else {
            // Only the generated package may have specializations set.
            for specialization in specializations {
                _ = emit(funcLit: specialization.generatedFunctionNode, entity: nil, specializationMangle: specialization.mangledName)
            }
/*
            let mangledName = entity.map(symbol) ?? ".fn"
            for specialization in specializations {
                if specialization.mangledName == nil {
                    let suffix = specialization.specializedTypes
                        .reduce("", { $0 + "$" + $1.description })
                    specialization.mangledName = mangledName + suffix
                }

                specialization.llvm = emit(funcLit: specialization.generatedFunctionNode, entity: entity, specializationMangle: specialization.mangledName)
            }
            return trap // dummy value. It doesn't matter.
*/
            return
        }

        for node in topLevelNodes {
            emit(topLevelStmt: node)
        }

        if compiler.options.isTestMode && package.isInitialPackage {
            synthTestMain()
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
            guard !d.emitted else {
                return
            }
            emit(declaration: d)
        case let testCase as TestCase:
            if compiler.options.isTestMode {
                let fn = emit(testCase: testCase)
                testCases.append(fn)
            }
        default:
            print("Warning: statement didn't codegen: \(stmt)")
        }
    }

    mutating func emit(decl: Decl) {
        switch decl {
        case let d as Declaration:
            emit(declaration: d)
        case let b as DeclBlock:
            emit(declBlock: b)
        case let f as Foreign:
            emit(foreign: f)
        default:
            fatalError("Unrecognized instance of Decl")
        }
    }

    mutating func emit(declBlock b: DeclBlock) {
        for decl in b.decls {
            emit(declaration: decl)
        }
    }

    mutating func emit(constantDecl decl: Declaration) {

        // ignore main while in test mode
        if isInvokationFile && decl.names.first?.name == "main" && compiler.options.isTestMode {
            return
        }

        if decl.values.isEmpty {
            // this is in a decl block of some sort
            for entity in decl.entities where entity !== Entity.anonymous {
                if let fn = entity.type as? ty.Function {
                    let function = addOrReuseFunction(named: symbol(for: entity), type: canonicalizeSignature(fn))
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
                    var globalValue = b.addGlobal(symbol(for: entity), type: canonicalize(entity.type!))
                    globalValue.isExternallyInitialized = true
                    globalValue.isGlobalConstant = true
                    entity.value = globalValue
                }
            }
            return
        }

        // Call to function to set (constant) values.
        if decl.values.count == 1, let call = decl.values.first as? Call {
            if decl.entities.count > 1 {
                let aggregate = emit(call: call)

                for (index, entity) in decl.entities.enumerated()
                    where entity !== Entity.anonymous
                {
                    entity.value = const.extractValue(aggregate, indices: [index])
                }
            } else {

                decl.entities[0].value = emit(call: call)
            }
            return
        }

        for (entity, value) in zip(decl.entities, decl.values) where entity.name == "main" || entity !== Entity.anonymous {
            if let type = entity.type as? ty.Metatype {

                switch baseType(type.instanceType) {
                case let type as ty.Struct:
                    let irType = b.createStruct(name: symbol(for: entity))
                    var irTypes: [IRType] = []
                    for field in type.fields.orderedValues {
                        let fieldType = canonicalize(field.type)
                        irTypes.append(fieldType)
                    }
                    irType.setBody(irTypes, isPacked: type.isPacked)

                case is ty.Enum:
                    return
// TODO: Create global values for enum types and expose them in TypeInfo
//                    let sym = symbol(for: entity)
//                    let type = IntType(width: e.width!, in: module.context)
//                    let irType = b.createStruct(name: sym, types: [type], isPacked: true)
//                    var globals: [Global] = []
//                    for c in e.cases {
//                        let name = sym.appending("." + c.ident.name)
//                        let value = irType.constant(values: [type.constant(c.number)])
//                        let global = b.addGlobal(name, initializer: value)
//                        globals.append(global)
//                    }
//                    _ = b.addGlobal(sym.appending("..cases"), initializer: LLVM.ArrayType.constant(globals, type: irType))
//                    if let associatedType = e.associatedType, !(associatedType is ty.Integer)  {
//                        var associatedGlobals: [Global] = []
//                        for c in e.cases {
//                            let name = sym.appending("." + c.ident.name).appending(".raw")
//                            var ir: IRValue
//                            switch c.constant {
//                            case let val as String:
//                                ir = emit(constantString: val)
//                            case let val as Double:
//                                ir = canonicalize(associatedType as! ty.FloatingPoint).constant(val)
//                            default:
//                                fatalError()
//                            }
//                            let global = b.addGlobal(name, initializer: ir)
//                            associatedGlobals.append(global)
//                        }
//                        _ = b.addGlobal(sym.appending("..associated"), initializer: LLVM.ArrayType.constant(associatedGlobals, type: canonicalize(associatedType)))
//                    }

                default:
                    // Type alias
                    break
                }
                return
            } else if let type = entity.type as? ty.Function, !(value is FuncLit),
                let valueEntity = (value as? Ident)?.entity ?? (value as? Selector)?.sel.entity, valueEntity.isConstant {
                // Messy check for aliasing functions

                guard valueEntity.package !== package else {
                    entity.value = valueEntity.value
                    return
                }
                let irType = canonicalizeSignature(type)

                // If the entity on the rhs has a custom linkname create a stub for the linker to resolve
                if let linkname = valueEntity.linkname {
                    entity.value = b.addFunction(linkname, type: irType)
                    return
                }

                // finally if none of that is the case, emit a stub for the rhs and an alias for the lhs
                let rhsStub = b.addFunction(valueEntity.mangledName, type: irType)
                entity.value = b.addAlias(name: symbol(for: entity), to: rhsStub, type: irType)
                return
            }

            if value is FuncLit, let type = entity.type as? ty.Function, !type.isPolymorphic {
                entity.value = b.addFunction(symbol(for: entity), type: canonicalizeSignature(type))
            }

            var ir = emit(expr: value, entity: entity)
            // functions are already global
            if !ir.isAFunction {
                var globalValue = b.addGlobal(symbol(for: entity), initializer: ir)
                globalValue.isGlobalConstant = true
                ir = globalValue
            }

            entity.value = ir
        }
    }

    mutating func emit(variableDecl decl: Declaration) {
        if decl.values.count == 1, let call = decl.values.first as? Call, decl.entities.count > 1 {
            let retType = canonicalize(call.type)
            let stackAggregate = entryBlockAlloca(type: retType)
            let aggregate = emit(call: call)
            b.buildStore(aggregate, to: stackAggregate)

            for (index, entity) in decl.entities.enumerated()
                where entity !== Entity.anonymous
            {
                let type = canonicalize(entity.type!)

                // TODO: Linkname
                if entity.owningScope.isFile {
                    var global = b.addGlobal(symbol(for: entity), type: type)
                    global.initializer = type.undef()
                    entity.value = global
                } else {
                    let stackValue = entryBlockAlloca(type: type, name: entity.name)
                    let rvaluePtr = b.buildStructGEP(stackAggregate, index: index)
                    let rvalue = buildLoad(rvaluePtr)

                    b.buildStore(rvalue, to: stackValue)

                    entity.value = stackValue
                }
            }
            return
        }

        if decl.values.isEmpty {
            for entity in decl.entities where entity !== Entity.anonymous {
                let type = canonicalize(entity.type!)
                if entity.owningScope.isFile || entity.owningScope.isPackage {
                    var global = b.addGlobal(symbol(for: entity), type: type)
                    if entity.isForeign {
                        global.isExternallyInitialized = true
                    } else {
                        global.initializer = type.undef()
                    }
                    entity.value = global
                } else {
                    entity.value = entryBlockAlloca(type: type)
                }
            }
            return
        }

        // NOTE: Uninitialized values?
        assert(decl.entities.count == decl.values.count)
        for (entity, value) in zip(decl.entities, decl.values) where entity !== Entity.anonymous {

            // FIXME: Is it actually possible to encounter a metatype as the rhs of a variable declaration?
            //   if it is we should catch that in the checker for declarations
            if let t = entity.type, let type = baseType(t) as? ty.Metatype {
                let irType = b.createStruct(name: symbol(for: entity))

                switch type.instanceType {
                case let type as ty.Struct:
                    var irTypes: [IRType] = []
                    for field in type.fields.orderedValues.sorted(by: { $0.index < $1.index }) {
                        let fieldType = canonicalize(field.type)
                        irTypes.append(fieldType)
                    }
                    irType.setBody(irTypes)

                default:
                    preconditionFailure()
                }
                return
            }

            let type = canonicalize(entity.type!)

            let ir = emit(expr: value, entity: entity)
            if entity.owningScope.isFile || entity.owningScope.isPackage {
                // FIXME: What should we do for things like global variable strings? They need to be mutable?
                var global = b.addGlobal(symbol(for: entity), type: type)
                if entity.isForeign {
                    global.isExternallyInitialized = true
                } else {
                    global.initializer = ir
                }
                entity.value = global
            } else {
                let stackValue = entryBlockAlloca(type: type, name: symbol(for: entity))

                entity.value = stackValue

                b.buildStore(ir, to: stackValue)
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
        declaration.emitted = true
    }

    mutating func emit(statement stmt: Stmt) {
        switch stmt {
        case is Empty, is Using: return
        case let ret as Return:
            emit(return: ret)
        case let d as Defer:
            emit(defer: d)
        case let stmt as ExprStmt:
            // return address so that we don't bother with the load
            _ = emit(expr: stmt.expr)
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
        case let forIn as ForIn:
            emit(forIn: forIn)
        case let íf as If:
            emit(if: íf)
        case let s as Switch:
            emit(switch: s)
        case let b as Branch:
            emit(branch: b)
        case let a as InlineAsm:
            _ = emit(inlineAsm: a, returnAddress: false)
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
                b.buildStore(rvaluePtr, to: lvalueAddress)
                return
            }

            let retType = canonicalize(call.type)
            let stackAggregate = entryBlockAlloca(type: retType)
            let aggregate = emit(call: call)
            b.buildStore(aggregate, to: stackAggregate)

            for (index, lvalue) in assign.lhs.enumerated()
                where (lvalue as? Ident)?.name != "_"
            {
                let lvalueAddress = emit(expr: lvalue, returnAddress: true)
                let rvaluePtr = b.buildStructGEP(stackAggregate, index: index)
                let rvalue = buildLoad(rvaluePtr)
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
        guard !ret.results.isEmpty else { // void return
            b.buildBr(context.deferBlocks.last ?? context.returnBlock!)
            return
        }

        var values: [IRValue] = []
        for value in ret.results {
            let irValue = emit(expr: value)
            values.append(irValue)
        }

        let result = b.currentFunction!.entryBlock!.firstInstruction!
        assert(result.isAAllocaInst && result.name == "result")
        switch values.count {
        case 1:
            b.buildStore(values[0], to: result)

        default:
            for (index, value) in values.enumerated() {
                let elPtr = b.buildStructGEP(result, index: index)
                b.buildStore(value, to: elPtr)
            }
        }
        b.buildBr(context.deferBlocks.last ?? context.returnBlock!)
    }

    mutating func emit(defer d: Defer) {
        let f = b.currentFunction!
        let prevBlock = b.insertBlock!
        let block = f.appendBasicBlock(named: "defer", in: module.context)

        b.positionAtEnd(of: block)

        emit(statement: d.stmt)
        b.buildBr(context.deferBlocks.last ?? context.returnBlock!)

        b.positionAtEnd(of: prevBlock)

        context.deferBlocks.append(block)
    }

    mutating func emit(if iff: If) {

        let thenBlock = b.currentFunction!.appendBasicBlock(named: "if.then", in: module.context)
        let elseBlock = iff.els.map({ _ in b.currentFunction!.appendBasicBlock(named: "if.else", in: module.context) })
        let postBlock = b.currentFunction!.appendBasicBlock(named: "if.post", in: module.context)

        let cond = emit(expr: iff.cond)
        b.buildCondBr(condition: b.buildTruncOrBitCast(cond, type: i1), then: thenBlock, else: elseBlock ?? postBlock)

        b.positionAtEnd(of: thenBlock)
        emit(statement: iff.body)

        if b.insertBlock!.terminator == nil {
            b.buildBr(postBlock)
        }

        if let els = iff.els {
            b.positionAtEnd(of: elseBlock!)
            emit(statement: els)

            if elseBlock!.terminator == nil {
                b.buildBr(postBlock)
            }
        }

        // fixes if a else if b emitting bad IR
        if b.insertBlock?.terminator == nil {
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
            loopCond = currentFunc.appendBasicBlock(named: "for.cond", in: module.context)
            if f.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step", in: module.context)
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body", in: module.context)
            loopPost = currentFunc.appendBasicBlock(named: "for.post", in: module.context)

            b.buildBr(loopCond!)
            b.positionAtEnd(of: loopCond!)

            let cond = emit(expr: condition)
            b.buildCondBr(condition: b.buildTruncOrBitCast(cond, type: i1), then: loopBody, else: loopPost)
        } else {
            if f.step != nil {
                loopStep = currentFunc.appendBasicBlock(named: "for.step", in: module.context)
            }

            loopBody = currentFunc.appendBasicBlock(named: "for.body", in: module.context)
            loopPost = currentFunc.appendBasicBlock(named: "for.post", in: module.context)

            b.buildBr(loopBody)
        }

        b.positionAtEnd(of: loopBody)
        defer {
            loopPost.moveAfter(b.currentFunction!.lastBlock!)
        }

        f.breakLabel.value = loopPost
        f.continueLabel.value = loopStep ?? loopCond ?? loopBody

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

    mutating func emit(forIn f: ForIn) {
        let currentFunc = b.currentFunction!

        var loopBody: BasicBlock
        var loopPost: BasicBlock
        var loopCond: BasicBlock
        var loopStep: BasicBlock

        let index = entryBlockAlloca(type: i64, name:  f.index?.ident.name ?? "i")
        f.index?.value = index
        _ = b.buildStore(i64.zero(), to: index)

        let element = entryBlockAlloca(type: canonicalize(f.element.type!), name: f.element.ident.name)
        f.element.value = element

        let agg: IRValue
        let len: IRValue

        switch f.checked {
        case .array(let length):
            agg = emit(expr: f.aggregate, returnAddress: true)
            len = i64.constant(length)
        case .slice:
            let aggBox = emit(expr: f.aggregate, returnAddress: true)
            let aggPtr = b.buildStructGEP(aggBox, index: 0)
            agg = buildLoad(aggPtr)
            let lenPtr = b.buildStructGEP(aggBox, index: 1)
            len = buildLoad(lenPtr)
        case .enumeration:
            fatalError("Unimplemented")
        case .invalid:
            return // FIXME: We should check the body to provide errors anyway
        }

        loopCond = currentFunc.appendBasicBlock(named: "for.cond", in: module.context)
        loopStep = currentFunc.appendBasicBlock(named: "for.step", in: module.context)
        loopBody = currentFunc.appendBasicBlock(named: "for.body", in: module.context)
        loopPost = currentFunc.appendBasicBlock(named: "for.post", in: module.context)

        b.buildBr(loopCond)
        b.positionAtEnd(of: loopCond)

        let withinBounds = b.buildICmp(buildLoad(index), len, .signedLessThan)
        b.buildCondBr(condition: withinBounds, then: loopBody, else: loopPost)

        b.positionAtEnd(of: loopBody)
        defer {
            loopPost.moveAfter(b.currentFunction!.lastBlock!)
        }

        f.breakLabel.value = loopPost
        f.continueLabel.value = loopCond

        let indexLoad = buildLoad(index)
        let indices: [IRValue]
        switch f.checked {
        case .array: indices = [0, indexLoad]
        default: indices = [indexLoad]
        }
        let elPtr = b.buildGEP(agg, indices: indices)
        b.buildStore(buildLoad(elPtr), to: element)
        emit(statement: f.body)

        let hasJump = b.insertBlock?.terminator != nil
        if !hasJump {
            b.buildBr(loopStep)
        }

        b.positionAtEnd(of: loopStep)
        let val = b.buildAdd(buildLoad(index), i64.constant(1))
        b.buildStore(val, to: index)
        b.buildBr(loopCond)

        b.positionAtEnd(of: loopPost)
    }

    mutating func emit(switch sw: Switch) {
        // NOTE: Also check some sort of flag to ensure things are constant integers otherwise LLVM switch doesn't work
        if sw.match == nil {
            fatalError("Boolean Switch not yet implemented for emission")
        }

        let curFunction = b.currentFunction!
        let curBlock = b.insertBlock!

        let postBlock = curFunction.appendBasicBlock(named: "switch.post", in: module.context)
        defer {
            postBlock.moveAfter(curFunction.lastBlock!)
        }
        sw.label.value = postBlock

        var thenBlocks: [BasicBlock] = []
        for c in sw.cases {
            if !c.match.isEmpty {
                let thenBlock = curFunction.appendBasicBlock(named: "switch.then.\(c.match[0])", in: module.context)
                thenBlocks.append(thenBlock)
            } else {
                let thenBlock = curFunction.appendBasicBlock(named: "switch.default", in: module.context)
                thenBlocks.append(thenBlock)
            }
        }

        var value: IRValue
        var tag: IRValue?
        if sw.isUnion {
            let union = baseType(sw.match!.type) as! ty.Union
            let tagType = canonicalize(union.tagType)
            value = emit(expr: sw.match!, returnAddress: true)
            tag = b.buildBitCast(value, type: LLVM.PointerType(pointee: tagType))
            tag = buildLoad(tag!)
        } else if sw.isAny {
            value = emit(expr: sw.match!, returnAddress: true)
            var ti = b.buildStructGEP(value, index: 1)
            ti = buildLoad(ti)
            tag = b.buildExtractValue(ti, index: 0)
        } else if let match = sw.match {
            value = emit(expr: match)
        } else {
            value = i1.constant(1)
        }

        var matches: [[IRValue]] = []
        for (i, c, nextCase) in sw.cases.enumerated().map({ ($0.offset, $0.element, sw.cases[safe: $0.offset + 1]) }) {
            let thenBlock = thenBlocks[i]
            nextCase?.label.value = thenBlocks[safe: i + 1]
            b.positionAtEnd(of: thenBlock)

            if sw.isUnion && !c.match.isEmpty {
                let match = c.match[0] as! Ident
                let union = baseType(sw.match!.type) as! ty.Union
                let tag = canonicalize(union.tagType).constant(match.constant! as! UInt64)
                matches.append([tag])
                if union.isInlineTag, let binding = c.binding {
                    let type = LLVM.PointerType(pointee: canonicalize(binding.type!))
                    binding.value = b.buildBitCast(value, type: type)

                    // Mask the inline tag
                    let valuePtr = b.buildStructGEP(value, index: 0)
                    let value = buildLoad(valuePtr)
                    let mask: UInt64 = ~maxValueForInteger(width: union.tagType.width!, signed: false)
                    let masked = b.buildAnd(value, canonicalize(union.dataType).constant(mask))
                    b.buildStore(masked, to: valuePtr)
                    
                } else if let binding = c.binding {
                    let dataPointer = b.buildStructGEP(value, index: 1)
                    let targetType = LLVM.PointerType(pointee: canonicalize(binding.type!))
                    binding.value = b.buildBitCast(dataPointer, type: targetType)
                    // FIXME: We need to decide on alignment rules for both union tags and values
                }
            } else if sw.isAny {
                var vals: [IRValue] = []
                for match in c.match {
                    let tiPtr = builtin.types.llvmTypeInfo(match.type.lower(), gen: &self)
                    let ti = const.extractValue(tiPtr, indices: [0])
                    vals.append(ti)
                }
                matches.append(vals)
                if let binding = c.binding {
                    let type = LLVM.PointerType(pointee: canonicalize(binding.type!))
                    let dataAddrPtr = b.buildStructGEP(value, index: 0)
                    let dataPtr = buildLoad(dataAddrPtr)
                    binding.value = b.buildBitCast(dataPtr, type: type)
                }

            } else if !c.match.isEmpty {
                var vals: [IRValue] = []
                for match in c.match {
                    vals.append(emit(expr: match))
                }
                matches.append(vals)
            }

            emit(statement: c.block)

            if b.insertBlock!.terminator == nil {
                b.buildBr(postBlock)
            }
            b.positionAtEnd(of: curBlock)
        }

        let hasDefaultCase = sw.cases.last!.match.isEmpty
        let irSwitch = b.buildSwitch(tag ?? value, else: hasDefaultCase ? thenBlocks.last! : postBlock, caseCount: thenBlocks.count)
        for (matches, block) in zip(matches, thenBlocks) {
            for match in matches {
                irSwitch.addCase(match, block)
            }
        }

        b.positionAtEnd(of: postBlock)
    }

    mutating func emit(branch: Branch) {
        b.buildBr(branch.target.value as! BasicBlock)
    }

    // MARK: Expressions

    mutating func emit(expr: Expr, returnAddress: Bool = false, entity: Entity? = nil) -> IRValue {
        var val: IRValue
        switch expr {
        case is Nil:
            val = canonicalize(expr.type).null()
        case let lit as BasicLit:
            val = emit(lit: lit, returnAddress: returnAddress, entity: entity)
        case let lit as CompositeLit:
            val = emit(lit: lit, returnAddress: returnAddress, entity: entity)
        case let ident as Ident:
            val = emit(ident: ident, returnAddress: returnAddress)
        case let paren as Paren:
            val = emit(expr: paren.element, returnAddress: returnAddress, entity: entity)
        case let unary as Unary:
            val = emit(unary: unary, returnAddress: returnAddress)
        case let binary as Binary:
            val = emit(binary: binary)
        case let ternary as Ternary:
            val = emit(ternary: ternary)
        case let fn as FuncLit:
            val = emit(funcLit: fn, entity: entity)
        case let call as Call:
            val = emit(call: call, returnAddress: returnAddress)
        case let sel as Selector:
            val = emit(selector: sel, returnAddress: returnAddress)
        case let sub as Subscript:
            val = emit(subscript: sub, returnAddress: returnAddress)
        case let slice as Slice:
            val = emit(slice: slice, returnAddress: returnAddress)
        case let l as LocationDirective:
            val = emit(locationDirective: l, returnAddress: returnAddress)
        case let cast as Cast:
            if cast.kind == .bitcast {
                val = emit(bitcast: cast, returnAddress: returnAddress)
            } else {
                assert(cast.kind == .cast || cast.kind == .autocast)
                val = emit(cast: cast, returnAddress: returnAddress)
            }
        case let asm as InlineAsm:
            val = emit(inlineAsm: asm, returnAddress: returnAddress)
        case let v as VariadicType:
            val = emit(expr: v.explicitType, returnAddress: returnAddress)
        default:
            preconditionFailure()
        }

        if let conversion = (expr as? Convertable)?.conversion {
            assert(!returnAddress, "Likely a bug in the checker. Be suspicious.")
            // FIXME: We want to ditch perform conversion
            val = performConversion(from: conversion.from, to: conversion.to, with: val)
        }

        return val
    }

    mutating func emit(lit: BasicLit, returnAddress: Bool, entity: Entity?) -> IRValue {
        // TODO: Use the mangled entity name
        if lit.token == .string {
            if isInteger(lit.type), let val = lit.constant as? UInt64 {
                assert(!returnAddress) // NOTE: This probably shouldn't make it past the frontend. It falls under taking the address of a literal number.
                return canonicalize(lit.type as! ty.Integer).constant(val)
            } else {
                // NOTE: The following code closely matches the code for emitting slices. Because Strings are slices.
                assert(lit.type == ty.string)
                let str = lit.constant as! String
                let arrayIr = LLVM.ArrayType.constant(string: str, in: module.context)
                var global = b.addGlobal(".str.raw", initializer: arrayIr)
                global.linkage = .private
                global.isGlobalConstant = entity?.isConstant ?? false
                let irType = canonicalize(ty.string) as! LLVM.StructType

                // NOTE: Length and Capacity are always constants!
                let ir = irType.constant(values: [
                    const.inBoundsGEP(global, indices: [i64.constant(0), i64.constant(0)]),
                    i64.constant(str.utf8.count),
                    i64.constant(0), // NOTE: We set the capacity to zero to signify that the data pointer is not managed by an allocator
                ])

                assert(entity != nil && entity!.isConstant, implies: ir.isConstant, "The value being emitted for the entity \(entity!.name) was not constant, but should have been")

                if returnAddress {
                    return makeAddressable(value: ir, entity: entity)
                }
                return ir
            }
        }

        assert(!returnAddress)
        let type = canonicalize(lit.type)
        switch type {
        case let type as IntType:
            let val = type.constant(lit.constant as! UInt64)
            return val
        case let type as FloatType:
            switch lit.constant {
            case let constant as Double:
                return type.constant(constant)

            case let constant as UInt64:
                return type.constant(Double(constant))

            default:
                fatalError()
            }
        default:
            preconditionFailure()
        }
    }

    mutating func emit(lit: CompositeLit, returnAddress: Bool, entity: Entity?) -> IRValue {
        // TODO: Use the mangled entity name
        // TODO: Respect `returnAddress` for all of the following
        switch baseType(lit.type) {
        case is ty.Struct:
            let irType = canonicalize(lit.type) as! LLVM.StructType
            var ir = irType.undef()
            for el in lit.elements {
                let val = emit(expr: el.value)
                // NOTE: Swift doesn't offer a great way to share memory without also storing a tag to decern the value
                guard case .structField(let field) = el.checked else { fatalError() }
                // NOTE: For constants LLVM will reliably constant fold this.
                ir = b.buildInsertValue(aggregate: ir, element: val, index: field.index)
            }
            assert(entity != nil && entity!.isConstant, implies: ir.isConstant, "The value being emitted for the entity \(entity!.name) was not constant, but should have been")

            if returnAddress {
                return makeAddressable(value: ir, entity: entity)
            }
            return ir

        case let unionType as ty.Union:
            let irType = canonicalize(unionType)
            assert(lit.elements.count == 1)
            // NOTE: Swift doesn't offer a great way to share memory without also storing a tag to decern the value
            guard case .unionCase(let unionCase) =  lit.elements[0].checked else { fatalError() }

            let unionData = emit(expr: lit.elements[0].value, returnAddress: false)

            var ir = irType.constant(values: [
                canonicalize(unionType.tagType).constant(unionCase.tag),
                irType.elementTypes[1].undef(),
            ])

            let converted = performConversion(from: unionCase.type, to: unionType.dataType, with: unionData)

            ir = b.buildInsertValue(aggregate: ir, element: converted, index: 1)

            if returnAddress {
                return makeAddressable(value: ir, entity: entity)
            }
            return ir

        case is ty.Array:
            let irType = canonicalize(lit.type) as! LLVM.ArrayType
            var ir: IRValue
            if !lit.elements.isEmpty {
                // Zero initialize the array
                ir = irType.null()
            } else {
                ir = irType.undef()
                for (index, el) in lit.elements.enumerated() {
                    let val = emit(expr: el.value)
                    // NOTE: For constants LLVM will reliably constant fold this.
                    ir = b.buildInsertValue(aggregate: ir, element: val, index: index)
                }
            }
            assert(entity != nil && entity!.isConstant, implies: ir.isConstant, "The value being emitted for the entity \(entity!.name) was not constant, but should have been")

            if returnAddress {
                return makeAddressable(value: ir, entity: entity)
            }
            return ir

        case let slice as ty.Slice:
            let irType = canonicalize(lit.type) as! LLVM.StructType
            let elType = canonicalize(slice.elementType)
            var arrayIr = LLVM.ArrayType(elementType: elType, count: lit.elements.count).undef()
            for (index, el) in lit.elements.enumerated() {
                let val = emit(expr: el.value)
                arrayIr = b.buildInsertValue(aggregate: arrayIr, element: val, index: index)
            }

            // Acquire a pointer to the array
            let arrayPtr: IRValue
            if let entity = entity, entity.isConstant {
                var global = b.addGlobal(".slice.raw", initializer: arrayIr)
                global.isGlobalConstant = true
                global.linkage = .private
                arrayPtr = const.inBoundsGEP(global, indices: [i64.constant(0), i64.constant(0)])
            } else if context.returnBlock == nil { // We are at a global scope
                var global = b.addGlobal(".slice.raw", initializer: arrayIr)
                global.linkage = .private
                arrayPtr = const.inBoundsGEP(global, indices: [i64.constant(0), i64.constant(0)])
            } else { // We are at function scope

                // NOTE: For now we are using malloc provided by LLVM, but we really want to be using a context allocator when we have those
                let heapAddress = b.buildMalloc(arrayIr.type)
                b.buildStore(arrayIr, to: heapAddress)
                arrayPtr = b.buildInBoundsGEP(heapAddress, indices: [i64.constant(0), i64.constant(0)])
            }

            // NOTE: Length and Capacity are always constants!
            var ir = irType.constant(values: [
                arrayPtr.type.undef(),
                i64.constant(lit.elements.count),
                i64.constant(0), // NOTE: We set the capacity to zero to signify that the data pointer is not managed by an allocator
            ])

            ir = b.buildInsertValue(aggregate: ir, element: arrayPtr, index: 0) // LLVM will constant fold this if possible.
            assert(entity != nil && entity!.isConstant, implies: ir.isConstant, "The value being emitted for the entity \(entity!.name) was not constant, but should have been")
            if returnAddress {
                return makeAddressable(value: ir, entity: entity)
            }
            return ir

        case is ty.Vector:
            let irType = canonicalize(lit.type) as! LLVM.VectorType
            var ir = irType.undef()
            for (index, el) in lit.elements.enumerated() {
                let val = emit(expr: el.value)
                ir = b.buildInsertElement(vector: ir, element: val, index: index)
            }
            if returnAddress {
                return makeAddressable(value: ir, entity: entity)
            }
            return ir

        default:
            preconditionFailure()
        }
    }

    mutating func emit(ident: Ident, returnAddress: Bool) -> IRValue {
        if returnAddress || ident.entity.isBuiltin || isFunction(ident.type) && ident.entity.isConstant {
            // refering to global functions should retrieve their address
            return value(for: ident.entity)
        }
        if ident.entity.isConstant {
            switch baseType(ident.type) {
            case let type as ty.Integer:
                return canonicalize(type).constant(ident.entity.constant as! UInt64)
            case let type as ty.UntypedInteger:
                return canonicalize(type).constant(ident.entity.constant as! UInt64)
            case let type as ty.Float:
                return canonicalize(type).constant(ident.entity.constant as! Double)
            case let type as ty.UntypedFloat:
                return canonicalize(type).constant(ident.entity.constant as! Double)
            case let type as ty.Enum:
                return canonicalize(type).constant(ident.entity.constant as! UInt64)
            default:
                break
            }
        }

        return buildLoad(value(for: ident.entity))
    }

    mutating func emit(unary: Unary, returnAddress: Bool) -> IRValue {
        let val = emit(expr: unary.element, returnAddress: unary.op == .and)
        switch unary.op {
        case .add:
            return val
        case .sub:
            // TODO: Overflow behaviour?
            return b.buildNeg(val)
        case .lss:
            if returnAddress {
                return val
            }
            return buildLoad(val)
        case .not:
            // TODO: Should we do more here? ie ensure only the lowermost bit is set?
            return b.buildNot(val)
        case .bnot:
            return b.buildNot(val)
        case .and: // return the address (handled above)
            return val
        default:
            preconditionFailure()
        }
    }

    mutating func emit(binary: Binary) -> IRValue {
        let lhs = emit(expr: binary.lhs)
        let rhs = emit(expr: binary.rhs)

        switch binary.op {
        case .add:
            return b.buildAdd(lhs, rhs, overflowBehavior: .default)
        case .sub:
            return b.buildSub(lhs, rhs, overflowBehavior: .default)
        case .mul:
            return b.buildMul(lhs, rhs, overflowBehavior: .default)
        case .quo:
            return b.buildDiv(lhs, rhs, signed: isSigned(binary.type), exact: false) // what even is exact?
        case .rem:
            return b.buildRem(lhs, rhs, signed: isSigned(binary.type))

        case .land:
            let x = b.buildAnd(lhs, rhs)
            return b.buildTruncOrBitCast(x, type: i1)
        case .lor:
            let x = b.buildOr(lhs, rhs)
            return b.buildTruncOrBitCast(x, type: i1)

        case .and:
            return b.buildAnd(lhs, rhs)
        case .or:
            return b.buildOr(lhs, rhs)
        case .xor:
            return b.buildXor(lhs, rhs)
        case .shl:
            return b.buildShl(lhs, rhs)
        case .shr:
            return b.buildShr(lhs, rhs)
            
        default:
            break
        }

        // Comparison operations

        if isInteger(binary.lhs.type) || isBoolean(binary.lhs.type) {
            let signed = isSigned(binary.type)
            let pred: IntPredicate
            switch binary.op {
            case .lss: pred = signed ? .signedLessThan : .unsignedLessThan
            case .gtr: pred = signed ? .signedGreaterThan : .unsignedGreaterThan
            case .leq: pred = signed ? .signedLessThanOrEqual : .unsignedLessThanOrEqual
            case .geq: pred = signed ? .signedGreaterThanOrEqual : .unsignedGreaterThanOrEqual
            case .eql: pred = .equal
            case .neq: pred = .notEqual
            default:   preconditionFailure()
            }
            return b.buildICmp(lhs, rhs, pred)
        } else {
            assert(isFloat(binary.lhs.type))
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
        }
    }

    mutating func emit(ternary: Ternary) -> IRValue {
        var cond = emit(expr: ternary.cond)
        let then = ternary.then.map({ emit(expr: $0) }) ?? cond
        let els  = emit(expr: ternary.els)

        // NOTE: Ternaries have to manually perform there conversion to boolean types
        if cond.type is LLVM.PointerType {
            cond = performConversion(from: ternary.cond.type, to: ty.bool, with: cond)
        }
        return b.buildSelect(b.buildTruncOrBitCast(cond, type: i1), then: then, else: els)
    }

    mutating func emit(args: [Expr], cABI: Bool) -> [IRValue] {
        let irArgs: [IRValue]
        if cABI {
            irArgs = args.map {
                var val = emit(expr: $0)

                // C ABI requires integers less than 32bits to be promoted
                if isInteger($0.type), $0.type.width! < 32 {
                    val = b.buildCast(isSigned($0.type) ? .sext : .zext, value: val, type: i32)
                }

                // C ABI requires floats to be promoted to doubles
                if isFloat($0.type), $0.type.width! < 64 {
                    val = b.buildCast(.fpext, value: val, type: f64)
                }

                // FIXME: We need to determine how to actually pass structs to C ABI functions

                // TODO: Struct ABI stuff?
                return val
            }
        } else {
            irArgs = args.map {
                let val = emit(expr: $0)
                return val
            }
        }

        return irArgs
    }

    mutating func emit(call: Call, returnAddress: Bool = false) -> IRValue {
        // FIXME: We need to convert unnamed types into named types in returns if necissary for aliases

        switch call.checked {
        case .invalid: preconditionFailure("Invalid checked member made it to IRGen")
        case .builtinCall(let builtin):
            return builtin.generate(builtin, returnAddress, call, &self)
        case .call:
            var isGlobal = false
            if let entity = entity(from: call.fun) {
                isGlobal = entity.isConstant
            }
            let callee = emit(expr: call.fun, returnAddress: isGlobal)

            // FIXME: Use the call convention instead of isCVariadic
            let fn = findConcreteType(baseType(call.fun.type)) as! ty.Function
            let shouldUseCABI = fn.isCVariadic

            var args = emit(args: call.args, cABI: shouldUseCABI)
            if fn.isVariadic && !fn.isCVariadic && !(call.args.last is VariadicType) {
                // bundle the excess args into a slice
                let requiredArgs = fn.params.count - 1
                let excessArgs = args[requiredArgs...]
                var val = canonicalize(fn.params.last!).undef()
                let sliceElementType = canonicalize((fn.params.last! as! ty.Slice).elementType)
                var ptr = LLVM.PointerType(pointee: sliceElementType).null()
                if !excessArgs.isEmpty {
                    let array = entryBlockAlloca(type: LLVM.ArrayType(elementType: sliceElementType, count: excessArgs.count))
                    for (index, arg) in excessArgs.enumerated() {
                        let target = b.buildInBoundsGEP(array, indices: [0, index])
                        b.buildStore(arg, to: target)
                    }
                    ptr = b.buildGEP(array, indices: [0, 0])
                }
                val = b.buildInsertValue(aggregate: val, element: ptr, index: 0)
                val = b.buildInsertValue(aggregate: val, element: excessArgs.count, index: 1)
                val = b.buildInsertValue(aggregate: val, element: excessArgs.count, index: 2)

                args = Array(args.dropLast(args.count - requiredArgs))
                args.append(val)
            }
            let val = b.buildCall(callee, args: args)
            if returnAddress {
                // allocate stack space to land this onto
                let type = canonicalize(call.type)
                let mem = b.buildAlloca(type: type)
                b.buildStore(val, to: mem)
                return mem
            }
            return val
        case .specializedCall(let specialization):

            var expectedParamTypes = ArraySlice(specialization.strippedType.params)
            // Because we use the param types below to lower any named IR types into their unnamed variants, we must
            //  have enough params of the right type to zip up with
            if specialization.strippedType.isVariadic && !specialization.strippedType.isCVariadic {
                expectedParamTypes = expectedParamTypes.dropLast()
                let variadicElementType = (specialization.strippedType.params.last! as! ty.Slice).elementType
                expectedParamTypes.append(contentsOf: repeatElement(variadicElementType, count: call.args.count - expectedParamTypes.count))
            }

            // The following maps a parameter to it's base type, if it is a named type in IR then this lowers it to an unamed type so that
            //  aliases in specialized functions result in a single specialization (string and []u8)
            var args = zip(call.args, expectedParamTypes).map { (arg, param) -> IRValue in
                var val: IRValue
                if arg.type is ty.Named && baseType(arg.type) is IRNamableType {
                    // we need to lower these
                    val = emit(expr: arg, returnAddress: true)
                    assert(val.type is LLVM.PointerType)

                    let irType = LLVM.PointerType(pointee: canonicalize(baseType(param)))
                    val = b.buildBitCast(val, type: irType)
                    val = buildLoad(val)
                } else {
                    val = emit(expr: arg)
                }

                return val
            }

            let fn = specialization.strippedType
            if fn.isVariadic && !fn.isCVariadic {
                // bundle the excess args into a slice
                let requiredArgs = fn.params.count - 1
                let excessArgs = args[requiredArgs...]
                var val = canonicalize(fn.params.last!).undef()
                let sliceElementType = canonicalize((fn.params.last! as! ty.Slice).elementType)
                var ptr = LLVM.PointerType(pointee: sliceElementType).null()
                if !excessArgs.isEmpty {
                    let array = entryBlockAlloca(type: LLVM.ArrayType(elementType: sliceElementType, count: excessArgs.count))
                    for (index, arg) in excessArgs.enumerated() {
                        let target = b.buildInBoundsGEP(array, indices: [0, index])
                        b.buildStore(arg, to: target)
                    }
                    ptr = b.buildGEP(array, indices: [0, 0])
                }
                val = b.buildInsertValue(aggregate: val, element: ptr, index: 0)
                val = b.buildInsertValue(aggregate: val, element: excessArgs.count, index: 1)
                val = b.buildInsertValue(aggregate: val, element: excessArgs.count, index: 2)

                args = Array(args.dropLast(args.count - requiredArgs))
                args.append(val)
            }

            // NOTE: We always emit a stub as all polymorphic specializations are emitted into a specialization package.
            let function = addOrReuseFunction(named: specialization.mangledName, type: canonicalizeSignature(specialization.strippedType))

            let result: IRValue = b.buildCall(function, args: args)
            if fn.returnType.types.first is ty.Void {
                return result
            }

            // FIXME: This get's around calls to functions that return `[]u8` but want to store that into a named `[]u8` such as `string`
            //  This can't just be a simple bitcast because LLVM does not allow bitcasts on aggregate types. Only on pointers to them.
            //  So we allocated some stack memory for now.
            var mem = entryBlockAlloca(type: result.type)
            b.buildStore(result, to: mem)
            let type = canonicalize(call.type)
            mem = b.buildBitCast(mem, type: LLVM.PointerType(pointee: type))
            return buildLoad(mem)
        }
    }

    mutating func emit(cast: Cast, returnAddress: Bool = false) -> IRValue {
        // FIXME: We shouldn't just return address for everything! There are lots of things we can't and it means we can't check against addressing in the IRGen
        //  The best solution may be to check the type of the cast.expr and then determine if we should attempt to return the address from that, alternatively check
        //   what kind of Ast Node the cast.expr is and use that.
        // @HACK: If it's a basic literal we ensure we don't attempt to return the address
        var value = emit(expr: cast.expr, returnAddress: !(cast.expr is BasicLit))

        var target = canonicalize(cast.type)
        if returnAddress {
            target = LLVM.PointerType(pointee: target)
        } else if (value.type as? LLVM.PointerType)?.pointee is LLVM.StructType {
            // if it's a struct we must cast the pointer and perform a load
            // LLVM doesn't let you bitcast any aggregate types, so the pointer must be reinterpreted
            let pointer = b.buildBitCast(value, type: LLVM.PointerType(pointee: target))
            return buildLoad(pointer)
        } else if !isAddressOfExpr(cast.expr) && value.type is LLVM.PointerType && !value.isAFunction { // if casting an address of operator the precedence should swap
            value = buildLoad(value)
        }

        switch (value.type, target) {
        case (let from as LLVM.IntType, let target as LLVM.IntType):
            let trunc = from.width >= target.width
            if trunc {
                return b.buildTruncOrBitCast(value, type: target)
            }
            if isSigned(cast.expr.type) {
                return b.buildSExt(value, type: target)
            }
            return b.buildZExtOrBitCast(value, type: target)

        case (is LLVM.IntType, let target as LLVM.FloatType):
            return b.buildIntToFP(value, type: target, signed: isSigned(cast.expr.type))

        case (is LLVM.FloatType, let target as LLVM.IntType):
            return b.buildFPToInt(value, type: target, signed: isSigned(cast.type))

        case (is LLVM.FloatType, is LLVM.FloatType):
            return b.buildFPCast(value, type: target)

        case (is LLVM.IntType, let target as LLVM.PointerType):
            return b.buildIntToPtr(value, type: target)

        case (is LLVM.PointerType, let target as LLVM.IntType):
            return b.buildPtrToInt(value, type: target)

        case (is LLVM.PointerType, is LLVM.PointerType):
            return b.buildBitCast(value, type: target)

        case (is LLVM.FunctionType, is LLVM.PointerType),
             (is LLVM.FunctionType, is LLVM.FunctionType):
            return b.buildBitCast(value, type: target)

        // TODO: LLVM.VectorType's

        default:
            fatalError("Cast from type of \(cast.expr.type) to \(cast.type) unimplemented")
        }
    }

    mutating func emit(bitcast: Cast, returnAddress: Bool = false) -> IRValue {
        // FIXME: We shouldn't just return address for everything! There are lots of things we can't and it means we can't check against addressing in the IRGen
        //  The best solution may be to check the type of the cast.expr and then determine if we should attempt to return the address from that, alternatively check
        //   what kind of Ast Node the cast.expr is and use that.
        // @HACK: If it's a basic literal we ensure we don't attempt to return the address
        var value = emit(expr: bitcast.expr, returnAddress: true)

        var target = canonicalize(bitcast.type)
        if returnAddress {
            target = LLVM.PointerType(pointee: target)
        } else if let pointer = value.type as? LLVM.PointerType, pointer.pointee is LLVM.StructType || pointer.pointee is LLVM.FunctionType {
            // TODO: cleanup, there are other types here that are unhandled, like arrays and vectors
        } else if !isAddressOfExpr(bitcast.expr) && value.type is LLVM.PointerType && !value.isAFunction { // if casting an address of operator the precedence should swap
            value = buildLoad(value)
        } else if bitcast.type == bitcast.expr.type {
            return value // TODO: load?
        }

        switch (value.type, target) {
        case (is LLVM.IntType, let target as LLVM.IntType):
            return b.buildBitCast(value, type: target)

        case (is LLVM.IntType, let target as LLVM.FloatType):
            return b.buildIntToFP(value, type: target, signed: isSigned(bitcast.expr.type))

        case (is LLVM.FloatType, let target as LLVM.IntType):
            return b.buildFPToInt(value, type: target, signed: isSigned(bitcast.type))

        case (is LLVM.FloatType, is LLVM.FloatType):
            return b.buildFPCast(value, type: target)

        case (is LLVM.IntType, let target as LLVM.PointerType):
            return b.buildIntToPtr(value, type: target)

        case (is LLVM.PointerType, let target as LLVM.IntType):
            return b.buildPtrToInt(value, type: target)

        case (is LLVM.PointerType, is LLVM.PointerType):
            return b.buildBitCast(value, type: target)

        case (is LLVM.FunctionType, is LLVM.PointerType),
             (is LLVM.FunctionType, is LLVM.FunctionType):
            return b.buildBitCast(value, type: target)

            // TODO: LLVM.VectorType's & LLVM.ArrayType?

        default:
            return buildLoad(value)
//            fatalError("Cast from type of \(bitcast.expr.type) to \(bitcast.type) unimplemented")
        }
    }

    mutating func emit(inlineAsm: InlineAsm, returnAddress: Bool) -> IRValue {
        var args: [IRValue] = []
        var argTypes: [IRType] = []
        for arg in inlineAsm.arguments {
            let a = emit(expr: arg)
            let at = canonicalize(arg.type)
            args.append(a)
            argTypes.append(at)
        }

        let type = LLVM.FunctionType(argTypes: argTypes, returnType: canonicalize(inlineAsm.type))
        let asm = b.buildInlineAssembly(
            inlineAsm.asm.constant! as! String,
            type: type,
            constraints: inlineAsm.constraints.constant! as! String,
            hasSideEffects: true, needsAlignedStack: true
        )

        return b.buildCall(asm, args: args)
    }

    mutating func emit(testCase: TestCase) -> Function {
        let fnType = LLVM.FunctionType(argTypes: [], returnType: VoidType())
        let function = b.addFunction(testCase.name.constant as! String, type: fnType)

        let entryBlock = function.appendBasicBlock(named: "entry", in: module.context)
        let returnBlock = function.appendBasicBlock(named: "ret", in: module.context)

        b.positionAtEnd(of: returnBlock)
        b.buildRetVoid()

        b.positionAtEnd(of: entryBlock)

        pushContext(scopeName: "", returnBlock: returnBlock)
        emit(statement: testCase.body)
        if b.insertBlock?.terminator == nil {
            b.buildBr(context.deferBlocks.last ?? returnBlock)
        }
        popContext()

        returnBlock.moveAfter(function.lastBlock!)

        return function
    }

    mutating func emit(funcLit fn: FuncLit, entity: Entity?, specializationMangle: String? = nil) -> Function {
        switch fn.checked {
        case .invalid: preconditionFailure("Invalid checked member made it to IRGen")
        case .regular:
            let fnType = canonicalizeSignature(fn.type as! ty.Function)

            // NOTE: The entity.value should be set already for recursion
            let function = (entity?.value as? Function) ?? addOrReuseFunction(named: specializationMangle ?? entity.map(symbol) ?? ".fn", type: fnType)
            let prevBlock = b.insertBlock

            let isVoid = fnType.returnType is VoidType

            let entryBlock = function.appendBasicBlock(named: "entry", in: module.context)
            let returnBlock = function.appendBasicBlock(named: "ret", in: module.context)

            b.positionAtEnd(of: returnBlock)
            var resultPtr: IRValue?
            if isVoid {
                b.buildRetVoid()
            } else {
                resultPtr = entryBlockAlloca(type: fnType.returnType, name: "result")
                b.buildRet(buildLoad(resultPtr!))
            }

            b.positionAtEnd(of: entryBlock)

            for (param, var irParam) in zip(fn.params, function.parameters) {
                irParam.name = param.name
                param.value = entryBlockAlloca(type: irParam.type, name: param.name, default: irParam)
            }

            // TODO: Do we need to push a named context or can we reset the mangling because we are in a function scope?
            //  also should we use a mangled name if this is an anonymous fn?
            pushContext(scopeName: "", returnBlock: returnBlock)
            emit(statement: fn.body)
            if b.insertBlock?.terminator == nil {
                b.buildBr(context.deferBlocks.last ?? returnBlock)
            }
            popContext()

            returnBlock.moveAfter(function.lastBlock!)

            if let prevBlock = prevBlock {
                b.positionAtEnd(of: prevBlock)
            }

            passManager.run(on: function)

            return function

        case .polymorphic(_, _):
            /*
            let mangledName = entity.map(symbol) ?? ".fn"
            for specialization in specializations {
                if specialization.mangledName == nil {
                    let suffix = specialization.specializedTypes
                        .reduce("", { $0 + "$" + $1.description })
                    specialization.mangledName = mangledName + suffix
                }

                specialization.llvm = emit(funcLit: specialization.generatedFunctionNode, entity: entity, specializationMangle: specialization.mangledName)
            }
            */
            return trap // dummy value. It doesn't matter.
        }
    }

    mutating func emit(selector sel: Selector, returnAddress: Bool) -> IRValue {
        switch sel.checked {
        case .invalid: preconditionFailure("Invalid checked member made it to IRGen")
        case .file(let entity):
            if entity.isConstant {
                // FIXME: Switch on the actual constant value instead
                switch baseType(sel.type) {
                case let type as ty.Integer:
                    return canonicalize(type).constant(sel.constant as! UInt64)
                case let type as ty.UntypedInteger:
                    return canonicalize(type).constant(sel.constant as! UInt64)
                case let type as ty.Float:
                    return canonicalize(type).constant(sel.constant as! Double)
                case let type as ty.UntypedFloat:
                    return canonicalize(type).constant(sel.constant as! Double)
                default:
                    break // NOTE: Functions are constant values without a constant representation
                }
            }
            let address = value(for: entity)
            if returnAddress {
                return address
            }
            return buildLoad(address)

        case .anyData:
            let value = emit(expr: sel.rec, returnAddress: true)
            let dataAddress = b.buildStructGEP(value, index: 0)
            if returnAddress {
                return dataAddress
            }
            return buildLoad(dataAddress)

        case .anyType:
            let value = emit(expr: sel.rec, returnAddress: true)
            let dataAddress = b.buildStructGEP(value, index: 1)
            if returnAddress {
                return dataAddress
            }
            return buildLoad(dataAddress)

        case .struct(let field):
            var aggregate = emit(expr: sel.rec, returnAddress: true)
            for _ in 0 ..< sel.levelsOfIndirection {
                aggregate = buildLoad(aggregate)
            }
            let fieldAddress = b.buildStructGEP(aggregate, index: field.index)
            if returnAddress {
                return fieldAddress
            }
            return buildLoad(fieldAddress)
            
        case .enum(let c):
            return canonicalize(baseType(sel.type) as! ty.Enum).constant(c.constant)

        case .unionTag:
            var aggregate = emit(expr: sel.rec, returnAddress: true)
            for _ in 0 ..< sel.levelsOfIndirection {
                aggregate = buildLoad(aggregate)
            }
            let type = canonicalize(sel.type) as! LLVM.IntType // FIXME: Assumes tag type must be integer (Not checked in checker)
            let address = b.buildBitCast(aggregate, type: LLVM.PointerType(pointee: type))
            if returnAddress {
                return address
            }
            let mask = type.allOnes()
            let tag = buildLoad(address, alignment: 16)
            return b.buildAnd(mask, tag)

        case .union(let unionType, let unionCase):
            var aggregate = emit(expr: sel.rec, returnAddress: true)
            for _ in 0 ..< sel.levelsOfIndirection {
                aggregate = buildLoad(aggregate)
            }
            let type = canonicalize(unionCase.type)

            let address: IRValue
            if unionType.isInlineTag {
                address = b.buildBitCast(aggregate, type: LLVM.PointerType(pointee: type))
            } else {
                let dataAddress = b.buildStructGEP(aggregate, index: 1)
                address = b.buildBitCast(dataAddress, type: LLVM.PointerType(pointee: canonicalize(unionCase.type)))
            }
            if returnAddress {
                return address
            }
            return buildLoad(address)

        case .array(let member):
            var aggregate = emit(expr: sel.rec, returnAddress: true)
            for _ in 0 ..< sel.levelsOfIndirection {
                aggregate = buildLoad(aggregate)
            }
            let index = member.rawValue
            let fieldAddress = b.buildStructGEP(aggregate, index: index)
            if returnAddress {
                return fieldAddress
            }
            return buildLoad(fieldAddress)

        case .staticLength(let length):
            return i64.constant(length)

        case .scalar(let index):
            var vector = emit(expr: sel.rec, returnAddress: returnAddress)
            for _ in 0 ..< sel.levelsOfIndirection {
                vector = buildLoad(vector)
            }

            if returnAddress {
                return b.buildGEP(vector, indices: [i64.constant(0), i64.constant(index)])
            }

            return b.buildExtractElement(vector: vector, index: index)

        case .swizzle(let indices):
            var vector = emit(expr: sel.rec)
            for _ in 0 ..< sel.levelsOfIndirection {
                vector = buildLoad(vector)
            }

            let recType = canonicalize(findConcreteType(sel.rec.type))
            let maskType = canonicalize(sel.type)
            var shuffleMask = maskType.undef()
            for (i, index) in indices.enumerated() {
                shuffleMask = b.buildInsertElement(vector: shuffleMask, element: i32.constant(index), index: i)
            }

            let swizzle = b.buildShuffleVector(vector, and: recType.undef(), mask: shuffleMask)
            if returnAddress {
                let ptr = entryBlockAlloca(type: maskType)
                return b.buildStore(swizzle, to: ptr)
            }

            return swizzle
        }
    }

    mutating func emit(subscript sub: Subscript, returnAddress: Bool) -> IRValue {
        let aggregate: IRValue
        var index = emit(expr: sub.index)
        if sub.index.type.width! < word.width {
            // GEP is signed meaning using values that are unsigned where the top bit is
            //  set they are treated as negative by LLVM. To get around this we zero extend
            //  to the word size this permits indexing an array of bits up to 1024 Petabytes in size.
            index = b.buildZExt(index, type: word)
        }

        let indicies: [IRValue]

        // TODO: Array bounds checks
        switch baseType(sub.rec.type) {
        case is ty.Array:
            aggregate = emit(expr: sub.rec, returnAddress: true)
            indicies = [i64.zero(), index]

        case is ty.Slice:
            let structPtr = emit(expr: sub.rec, returnAddress: true)
            let arrayPtr = b.buildStructGEP(structPtr, index: 0)
            aggregate = buildLoad(arrayPtr)
            indicies = [index]

        case is ty.Pointer:
            aggregate = emit(expr: sub.rec)
            indicies = [index]

        default:
            preconditionFailure()
        }

        let val = b.buildInBoundsGEP(aggregate, indices: indicies)
        if returnAddress {
            return val
        }
        return buildLoad(val)
    }

    mutating func emit(slice: Slice, returnAddress: Bool) -> IRValue {
        var lo = slice.lo.map({ emit(expr: $0) })
        var hi = slice.hi.map({ emit(expr: $0) })

        // TODO: Array bounds checks

        var ptr: IRValue
        let len: IRValue
        let cap: IRValue
        switch baseType(slice.rec.type) {
        case let type as ty.Array:
            let rec = emit(expr: slice.rec, returnAddress: true)
            lo = lo ?? i64.zero()
            hi = hi ?? i64.constant(type.length)

            ptr = b.buildInBoundsGEP(rec, indices: [0, lo!])
            len = b.buildSub(hi!, lo!)
            cap = b.buildSub(i64.constant(type.length), lo!)

        case is ty.Slice:
            let rec = emit(expr: slice.rec, returnAddress: true)
            let prevLen = buildLoad(b.buildStructGEP(rec, index: 1))
            let prevCap = buildLoad(b.buildStructGEP(rec, index: 2))
            lo = lo ?? i64.zero()
            hi = hi ?? prevLen

            // load the address in the struct then offset it by lo
            ptr = buildLoad(b.buildStructGEP(rec, index: 0))
            ptr = b.buildGEP(ptr, indices: [lo!])
            len = b.buildSub(hi!, lo!)
            cap = b.buildSub(prevCap, lo!)

        default:
            preconditionFailure()
        }

        var val = canonicalize(slice.type).undef()
        val = b.buildInsertValue(aggregate: val, element: ptr, index: 0)
        val = b.buildInsertValue(aggregate: val, element: len, index: 1)
        val = b.buildInsertValue(aggregate: val, element: cap, index: 2)

        if returnAddress {
            let ptr = entryBlockAlloca(type: canonicalize(slice.type))
            _ = b.buildStore(val, to: ptr)
            return ptr
        }
        return val
    }

    mutating func emit(locationDirective l: LocationDirective, returnAddress: Bool = false) -> IRValue {
        switch l.kind {
        case .file:
            return emit(constantString: l.constant as! String, returnAddress: returnAddress)
        case .line:
            assert(!returnAddress)
            return (canonicalize(ty.untypedInteger) as! IntType).constant(l.constant as! UInt64)
        case .location:
            fatalError()
        case .function:
            return emit(constantString: l.constant as! String, returnAddress: returnAddress)
        default:
            fatalError()
        }
    }
}


// MARK: Emit helpers

extension IRGenerator {

    mutating func makeAddressable(value: IRValue, entity: Entity?) -> IRValue {
        if let entity = entity, entity.isConstant {
            assert(value.isConstant)
            var global = b.addGlobal(entity.mangledName ?? ".", initializer: value)
            global.isGlobalConstant = true
            return global
        } else if context.returnBlock == nil {
            return b.addGlobal(entity?.mangledName ?? ".", initializer: value)
        } else {
            return entryBlockAlloca(type: value.type, name: entity?.mangledName ?? "", default: value)
        }
    }

    mutating func emit(constantString value: String, returnAddress: Bool = false) -> IRValue {
        let len = value.utf8.count
        let str = LLVM.ArrayType.constant(string: value)
        var raw = b.addGlobal(".str.raw", initializer: str)
        raw.isGlobalConstant = true
        raw.linkage = .private

        let ptr = const.inBoundsGEP(raw, indices: [0, 0])

        let type = canonicalize(ty.string) as! LLVM.StructType
        let ir = type.constant(values: [ptr, len, 0])
        if returnAddress {
            var global = b.addGlobal(".str", initializer: ir)
            global.linkage = .private
            return global
        }
        return ir
    }

    mutating func performConversion(from: Type, to target: Type, with value: IRValue) -> IRValue {
        let type = canonicalize(target)
        switch (baseType(from), baseType(target)) {
        case (let from as ty.UntypedInteger, let target as ty.Integer):
            if from.width! == target.width! {
                return value
            }
            if from.width! > target.width! {
                return b.buildCast(.trunc, value: value, type: type)
            } else {
                return b.buildCast(.sext, value: value, type: type)
            }
        case (is ty.UntypedInteger, is ty.Float):
            return b.buildCast(.siToFP, value: value, type: type)
        case (is ty.UntypedInteger, is ty.Pointer):
            return b.buildIntToPtr(value, type: type as! LLVM.PointerType)

        case (let from as ty.UntypedFloat, let target as ty.Float):
            if from.width! == target.width! {
                return value
            }
            let ext = from.width! < target.width!
            return b.buildCast(ext ? .fpext : .fpTrunc, value: value, type: type)
        case (is ty.UntypedFloat, let target as ty.Integer):
            return b.buildCast(target.isSigned ? .fpToSI : .fpToUI, value: value, type: type)

        case (let from as ty.Boolean, let target as ty.Boolean):
            if from.width! == target.width! {
                return value
            }
            if from.width! > target.width! {
                return b.buildCast(.trunc, value: value, type: type)
            } else {
                return b.buildCast(.zext, value: value, type: type)
            }

        case (let from as ty.Integer, let target as ty.Integer):
            if from.width! == target.width! {
                return value
            }
            if from.width! > target.width! {
                return b.buildCast(.trunc, value: value, type: type)
            } else {
                return b.buildCast(from.isSigned ? .sext : .zext, value: value, type: type)
            }
        case (let from as ty.Integer, is ty.Float):
            return b.buildCast(from.isSigned ? .siToFP : .uiToFP, value: value, type: type)
        case (is ty.Integer, is ty.Pointer):
            return b.buildIntToPtr(value, type: type as! LLVM.PointerType)

        case (let from as ty.Float, let target as ty.Float):
            let ext = from.width! < target.width!
            return b.buildCast(ext ? .fpext : .fpTrunc, value: value, type: type)
        case (is ty.Float, let target as ty.Integer):
            return b.buildCast(target.isSigned ? .fpToSI : .fpToUI, value: value, type: type)

        case (is ty.Pointer, is ty.Boolean):
            // NOTE: We ptr to int to a intptr first because if we don't we only get the bits that are the resultant int size
            let intptr = b.buildPtrToInt(value, type: word)
            let truth = b.buildICmp(intptr, word.zero(), .unsignedGreaterThan)
            return b.buildZExtOrBitCast(truth, type: type as! IntType)
        case (is ty.Pointer, is ty.Integer):
            return b.buildPtrToInt(value, type: type as! IntType)
        case (is ty.Union, is ty.Integer):
            return b.buildPtrToInt(value, type: type as! IntType)
        case (is ty.Pointer, is ty.Pointer),
             (is ty.Pointer, is ty.Function):
            return b.buildBitCast(value, type: type)

        case (is ty.Function, is ty.Pointer),
             (is ty.Function, is ty.Function):
            return b.buildBitCast(value, type: type)

        // enums with an associated type perform conversions per that type
        // enums without an associated type may be converted to any Integer
        case (let from as ty.Enum, let target):
            return performConversion(from: from.backingType, to: target, with: value)

        case (_, is ty.Anyy):
            // We need a heap allocation here, for now we will use malloc from libc.
            // FIXME: the any type shouldn't always need to malloc, in the case of type smaller than a machine word
            //   they have their value stored in the memory for the data pointer
            let dataType = canonicalize(from)
            var dataPointer = b.buildMalloc(dataType)
            b.buildStore(value, to: dataPointer)
            dataPointer = b.buildBitCast(dataPointer, type: LLVM.PointerType.toVoid)

            let typeInfo = builtin.types.llvmTypeInfo(from, gen: &self)
            var aggregate = canonicalize(ty.any).undef()
            aggregate = b.buildInsertValue(aggregate: aggregate, element: dataPointer, index: 0)
            aggregate = b.buildInsertValue(aggregate: aggregate, element: typeInfo, index: 1)
            return aggregate

        default:
            return b.buildBitCast(value, type: type)
        }
    }
}


// MARK: LLVM Helpers

extension IRGenerator {

    /// - Note: Handles minimum sized loads for integers automatically
    public func buildLoad(_ ptr: IRValue, ordering: AtomicOrdering = .notAtomic, volatile: Bool = false, alignment: Int = 8, name: String = "") -> IRValue {
        var ptr = ptr
        guard let pointer = ptr.type as? LLVM.PointerType else {
            fatalError()
        }
        // integer, pointer, or floating-point type
//        assert(pointer.pointee is LLVM.IntType || pointer.pointee is LLVM.PointerType || pointer.pointee is LLVM.FloatType, "LLVM load instruction must be on a pointer to an integer, float or pointer type")

        // NOTE: the following is only necissary for atomic loads, however, bugs can occur even if the load is non Atomic
        let width = targetMachine.dataLayout.sizeOfTypeInBits(pointer.pointee)
        let minLoadWidth = width.nextLoadablePowerOfTwoAlignment()
        if width < minLoadWidth, pointer.pointee is LLVM.IntType {
            let newIntType = LLVM.IntType(width: minLoadWidth, in: module.context)
            ptr = b.buildBitCast(ptr, type: LLVM.PointerType(pointee: newIntType))
        }
        let loadInst = b.buildLoad(ptr, ordering: ordering, volatile: volatile, alignment: alignment, name: name)

        if width < minLoadWidth {
            return b.buildTrunc(loadInst, type: pointer.pointee)
        }
        return loadInst
    }
}


// MARK: Type canonicalization

extension IRGenerator {

    mutating func canonicalize(_ type: Type) -> IRType {

        if let named = type as? ty.Named, let mangledName = named.entity.mangledName, let existing = module.type(named: mangledName) {
            return existing
        }

        switch type {
        case let type as ty.Void:
            return canonicalize(type)
        case let type as ty.Boolean:
            return canonicalize(type)
        case let type as ty.Integer:
            return canonicalize(type)
        case let type as ty.Float:
            return canonicalize(type)
        case let type as ty.Anyy:
            return canonicalize(type)
        case let type as ty.Pointer:
            return canonicalize(type)
        case let type as ty.Array:
            return canonicalize(type)
        case let type as ty.Slice:
            return canonicalize(type)
        case let type as ty.Vector:
            return canonicalize(type)
        case let type as ty.Function:
            return canonicalize(type)
        case let type as ty.Struct:
            return canonicalize(type)
        case let type as ty.Enum:
            return canonicalize(type)
        case let type as ty.Union:
            return canonicalize(type)
        case let type as ty.Tuple:
            return canonicalize(type)
        case let type as ty.UntypedInteger:
            return canonicalize(type)
        case let type as ty.UntypedFloat:
            return canonicalize(type)
        case let type as ty.Named:
            if let mangledName = type.entity.mangledName, let existing = module.type(named: mangledName) {
                return existing
            } else if type.base is IRNamableType && type.entity.isBuiltin {
                // NOTE: `string` is a builtin IRNamableType
                let packed = (type.base as? ty.Struct)?.isPacked ?? false

                // Prepend a `.` so that builtin named types cannot collide
                type.entity.mangledName = "." + type.entity.name

                let irType = b.createStruct(name: type.entity.mangledName)
                let type = canonicalize(type.base) as! LLVM.StructType
                irType.setBody(type.elementTypes, isPacked: packed)
                return irType
            } else if type.base is IRNamableType {
                emit(decl: type.entity.declaration!)
                return module.type(named: type.entity.mangledName)!
            } else {
                return canonicalize(type.base)
            }
        case is ty.Polymorphic:
            fatalError("Polymorphic types must be specialized before reaching the IRGenerator")
        default:
            preconditionFailure()
        }
    }

    mutating func canonicalize(_ void: ty.Void) -> VoidType {
        return VoidType(in: module.context)
    }

    mutating func canonicalize(_ any: ty.Anyy) -> LLVM.StructType {
        let rawptr = canonicalize(ty.rawptr)
        let typeInfo = canonicalize(builtin.types.typeInfoType)
        return LLVM.StructType(elementTypes: [rawptr, typeInfo], isPacked: true, in: module.context)
    }

    mutating func canonicalize(_ boolean: ty.Boolean) -> IntType {
        return IntType(width: boolean.width!, in: module.context)
    }

    mutating func canonicalize(_ integer: ty.Integer) -> IntType {
        return IntType(width: integer.width!, in: module.context)
    }

    mutating func canonicalize(_ float: ty.Float) -> FloatType {
        switch float.width! {
        case 16: return FloatType(kind: .half, in: module.context)
        case 32: return FloatType(kind: .float, in: module.context)
        case 64: return FloatType(kind: .double, in: module.context)
        case 80: return FloatType(kind: .x86FP80, in: module.context)
        case 128: return FloatType(kind: .fp128, in: module.context)
        default: fatalError()
        }
    }

    mutating func canonicalize(_ pointer: ty.Pointer) -> LLVM.PointerType {
        if let fn = pointer.pointeeType as? ty.Function {
            return LLVM.PointerType(pointee: canonicalizeSignature(fn))
        }
        return LLVM.PointerType(pointee: canonicalize(pointer.pointeeType))
    }

    mutating func canonicalize(_ array: ty.Array) -> LLVM.ArrayType {
        return LLVM.ArrayType(elementType: canonicalize(array.elementType), count: array.length)
    }

    mutating func canonicalize(_ slice: ty.Slice) -> LLVM.StructType {
        let element = LLVM.PointerType(pointee: canonicalize(slice.elementType))
        // FIXME: Stop using compiler word size as target word size
        let systemWidthType = LLVM.IntType(width: MemoryLayout<Int>.size * 8, in: module.context)
        // { Element type, Length, Capacity }
        return LLVM.StructType(elementTypes: [element, systemWidthType, systemWidthType], in: module.context)
    }

    mutating func canonicalize(_ vector: ty.Vector) -> LLVM.VectorType {
        return LLVM.VectorType(elementType: canonicalize(vector.elementType), count: vector.size)
    }

    /// - Note: This exists because LLVM weirdly defines a function type but doesn't let you do anything with it.
    /// Instead you actually use a pointer to a function everywhere, even though the API's to create those still
    /// take just a FunctionType. /Sigh
    mutating func canonicalizeSignature(_ fn: ty.Function) -> FunctionType {
        var paramTypes: [IRType] = []

        let requiredParams = fn.isCVariadic ? fn.params[..<(fn.params.endIndex - 1)] : ArraySlice(fn.params)
        for param in requiredParams {
            let type = canonicalize(param)
            paramTypes.append(type)
        }
        let retType = canonicalize(fn.returnType)
        return FunctionType(argTypes: paramTypes, returnType: retType, isVarArg: fn.isCVariadic)
    }

    mutating func canonicalize(_ fn: ty.Function) -> LLVM.PointerType {
        let type = canonicalizeSignature(fn)
        return LLVM.PointerType(pointee: type)
    }

    /// - Returns: A StructType iff tuple.types > 1
    mutating func canonicalize(_ tuple: ty.Tuple) -> IRType {
        var types: [IRType] = []
        for type in tuple.types {
            let ir = canonicalize(type)
            types.append(ir)
        }
        switch types.count {
        case 1:
            return types[0]
        default:
            return LLVM.StructType(elementTypes: types, isPacked: true, in: module.context)
        }
    }

    mutating func canonicalize(_ struc: ty.Struct) -> LLVM.StructType {
        return LLVM.StructType(elementTypes: struc.fields.orderedValues.map({ canonicalize($0.type) }), isPacked: struc.isPacked, in: module.context)
    }

    mutating func canonicalize(_ e: ty.Enum) -> IntType {
        return IntType(width: e.width!, in: module.context)
    }

    mutating func canonicalize(_ u: ty.Union) -> LLVM.StructType {
        if u.isInlineTag {
            let data = LLVM.IntType(width: u.width!, in: module.context)
            return LLVM.StructType(elementTypes: [data])
        }
        let tag  = canonicalize(u.tagType)
        let data = canonicalize(u.dataType)
        return LLVM.StructType(elementTypes: [tag, data])
    }

    mutating func canonicalize(_ integer: ty.UntypedInteger) -> IntType {
        return IntType(width: integer.width!, in: module.context)
    }

    mutating func canonicalize(_ float: ty.UntypedFloat) -> FloatType {
        return FloatType(kind: .double, in: module.context)
    }
}
