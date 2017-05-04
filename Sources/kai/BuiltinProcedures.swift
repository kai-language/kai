
import LLVM

var builtinProcedures: [(Entity, irGen: (IRGenerator) -> (Entity) -> IRValue)] = {

    // These are later mapped into `[Entity]`
    let short: [(String, mangled: String, irGen: (IRGenerator) -> (Entity) -> IRValue, params: [(String, Type)], returns: [Type], isVariadic: Bool)] = [

        (
            "malloc", mangled: "malloc", irGen: IRGenerator.genForeign,
            params: [("size", Type.i32)],
            returns: [Type.pointer(to: Type.u8)],
            isVariadic: false
        ),
        (
            "free", mangled: "free", irGen: IRGenerator.genForeign,
            params: [("ptr", Type.pointer(to: Type.u8))],
            returns: [Type.void],
            isVariadic: false
        ),
        (
            "printf", mangled: "printf", irGen: IRGenerator.genForeign,
            params: [("format", Type.pointer(to: Type.u8)), ("args", Type.any)],
            returns: [Type.void],
            isVariadic: true
        ),
    ]

    return short.map { (name, mangledName, irGen, params, returns, isVariadic) in
        let entity = Entity(name: name, kind: .compiletime, owningScope: Scope.universal)
        entity.mangledName = mangledName

        let procScope = Scope(parent: Scope.universal)
        entity.childScope = procScope
        
        let paramEntities = params.map({ Entity(name: $0.0, kind: .runtime, type: $0.1, owningScope: procScope) })
        entity.type = Type(kind: .proc(params: paramEntities, returns: returns, isVariadic: isVariadic), width: 0)

        return (entity, irGen)
    }
}()

extension IRGenerator {

    /// Will just emit a point to link to.
    func genForeign(_ entity: Entity) -> IRValue {
        return builder.addFunction(entity.mangledName!, type: canonicalize(entity.type!) as! FunctionType)
    }

    func genMallocIr(_ entity: Entity) -> IRValue {

        let proc = builder.addFunction(entity.mangledName!, type: canonicalize(entity.type!) as! FunctionType)
        let entry = proc.appendBasicBlock(named: "entry")

        builder.positionAtEnd(of: entry)
        defer {
            builder.clearInsertionPosition()
        }

        
        let arg = proc.parameter(at: 0)!
        let memory = builder.buildMalloc(canonicalize(Type.u8), count: arg)
        builder.buildRet(memory)

        return proc
    }

    func genFreeIr(_ entity: Entity) -> IRValue {

        let proc = builder.addFunction(entity.mangledName!, type: canonicalize(entity.type!) as! FunctionType)
        let entry = proc.appendBasicBlock(named: "entry")

        builder.positionAtEnd(of: entry)
        defer {
            builder.clearInsertionPosition()
        }
        

        let arg = proc.parameter(at: 0)!
        builder.buildFree(arg)
        builder.buildRetVoid()

        return proc
    }
}

func declareBuiltinProcedures() {
    
    for (entity, _) in builtinProcedures {
        Scope.universal.insert(entity)
    }
}
