
import LLVM

extension Type {

    static let builtin: [Type] = {

        // NOTE(vdka): Order is important later.
                  /* Name,   size, line, flags */
        let short: [(String, UInt, UInt, Flag)] = [
            ("void", 0, 0, .none),
            ("bool", 1, 0, .boolean),

            ("i8",  1, 0, [.integer]),
            ("u8",  1, 0, [.integer, .unsigned]),
            ("i16", 2, 0, [.integer]),
            ("u16", 2, 0, [.integer, .unsigned]),
            ("i32", 4, 0, [.integer]),
            ("u32", 4, 0, [.integer, .unsigned]),
            ("i64", 8, 0, [.integer]),
            ("u64", 8, 0, [.integer, .unsigned]),

            ("f32", 4, 0, .float),
            ("f64", 8, 0, .float),

            ("int", UInt(MemoryLayout<Int>.size), 0, [.integer]),
            ("uint", UInt(MemoryLayout<Int>.size), 0, [.integer, .unsigned]),

            // FIXME(vdka): Currently strings are just pointers hence length 8 (will remain?)
            ("string", 8, 0, .string),

            ("unconstrBool",    0, 0, [.unconstrained, .boolean]),
            ("unconstrInteger", 0, 0, [.unconstrained, .integer]),
            ("unconstrFloat",   0, 0, [.unconstrained, .float]),
            ("unconstrString",  0, 0, [.unconstrained, .string]),
            ("unconstrNil",     0, 0, [.unconstrained]),

            ("any", 0, 0, .none),

            ("<invalid>", 0, 0, .none),
        ]

        return short.map { (name, size, lineNumber, flags) in
            let location = SourceLocation(line: lineNumber, column: 0, file: std.types)

            let width = size < 0 ? size : size * 8

            return Type(kind: .builtin(name), flags: flags, width: width, location: location)
        }
    }()

    // TODO(vdka): Once we support structs define what these look like.
    // static let typeInfo = Type(kind: .struct("TypeInfo"), flags: .none, width: 0, location: nil)

    static let void = builtin[0]

    static let bool = builtin[1]

    static let i8   = builtin[2]
    static let u8   = builtin[3]
    static let i16  = builtin[4]
    static let u16  = builtin[5]
    static let i32  = builtin[6]
    static let u32  = builtin[7]
    static let i64  = builtin[8]
    static let u64  = builtin[9]

    static let f32  = builtin[10]
    static let f64  = builtin[11]

    static let int  = builtin[12]
    static let uint = builtin[13]

    static let string = builtin[14]

    static let unconstrBool     = builtin[15]
    static let unconstrInteger  = builtin[16]
    static let unconstrFloat    = builtin[17]
    static let unconstrString   = builtin[18]
    static let unconstrNil      = builtin[19]

    static let any = builtin[20]

    static let invalid = builtin[21]
}


// MARK: Builtin Procedures

var builtinProcedures: [(Entity, irGen: (IRGenerator) -> (Entity) -> IRValue)] = {

    // These are later mapped into `[Entity]`
    let short: [(String, mangled: String, irGen: (IRGenerator) -> (Entity) -> IRValue, params: [(String, Type)], returns: [Type], isVariadic: Bool)] = [

        (
            "malloc", mangled: "malloc", irGen: IRGenerator.genForeign,
            params: [("size", Type.i32)],
            returns: [Type.pointer(to: Type.u8)],
            isVariadic: false
        ),
        ( // NOTE(vdka): This will need to be different dependent on the type of the value.
            // if it is a dynamic Array then we need to free at a predefined offset from the pointer we are given.
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
