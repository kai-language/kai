
import LLVM

extension Scope {

    static let universal = Scope(parent: nil)
}

func declareBuiltins() {

    for entity in builtinProcedures {
        Scope.universal.insert(entity)
    }
    // TODO(vdka): Create a stdtypes.kai file to refer to for location

    for type in Type.builtin {

        guard let location = type.location else {
            panic()
        }

        let e = Entity(name: type.description, location: location, kind: .compiletime, owningScope: Scope.universal)
        e.type = type
        Scope.universal.insert(e)
    }

    // It's complicated...
    Entity.typeInfo.type = Type.typeInfo.metatype
    Scope.universal.insert(Entity.typeInfo)

    Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: Scope.universal)
    Entity.declareBuiltinConstant(name: "false", value: .bool(false), scope: Scope.universal)

    var e: Entity
    e = Entity(name: "nil", location: .unknown, kind: .compiletime, owningScope: Scope.universal)
    e.type = Type.unconstrNil
    Scope.universal.insert(e)

    e = Entity(name: "_", location: .unknown, kind: .compiletime, owningScope: Scope.universal)
    e.type = Type.any
    Scope.universal.insert(e)
}

extension Type {

    static let builtin: [Type] = {

        // NOTE(vdka): Order is important later.

        // NOTE(vdka): This isn't exactly correct. But 32 bit is pretty rare now days
        //   Once we have a project on integrated circuit then we should fix this up.
        // Maybe LLVM has something here?
        let platformIntegerSize = UInt(MemoryLayout<Int>.size)
        let platformPointerSize = UInt(MemoryLayout<UnsafeRawPointer>.size)
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

            ("int", platformIntegerSize, 0, [.integer]),
            ("uint", platformIntegerSize, 0, [.integer, .unsigned]),

            // FIXME(vdka): Currently strings are just pointers hence length 8 (will remain?)
            ("string", 8, 0, .string),

            ("unconstrBool",    0, 0, [.unconstrained, .boolean]),
            ("unconstrInteger", 0, 0, [.unconstrained, .integer]),
            ("unconstrFloat",   0, 0, [.unconstrained, .float]),
            ("unconstrString",  0, 0, [.unconstrained, .string]),
            ("unconstrNil",     0, 0, [.unconstrained]),

            ("any", 0, 0, .none),

            ("rawptr", platformPointerSize, 0, [.pointer]),

            ("<invalid>", 0, 0, .none),
            ("<placeholder>", 0, 0, .none),
        ]

        return short.map { (name, size, lineNumber, flags) in
            let location = SourceLocation(line: lineNumber, column: 0, file: std.types)

            let width = size < 0 ? size : size * 8

            return Type(kind: .builtin(name), flags: flags, width: width, location: location)
        }
    }()

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
    
    static let rawptr = builtin[21]

    static let invalid = builtin[22]
    static let placeholder = builtin[23]

    var metatype: Type {
        guard case .instance(let type) = kind else {
            return Type.typeInfo
        }
        
        return type
    }

    static let typeInfo: Type = {
        let s = Scope(parent: nil)

        let name = Entity(name: "name", kind: .compiletime, type: Type.string, owningScope: s)
        let width = Entity(name: "width", kind: .compiletime, type: Type.u64, owningScope: s)

        s.insert(name)
        s.insert(width)

        var totalWidth: UInt = 0
        for (index, entity) in s.elements.orderedValues.enumerated() {
            entity.offsetInParent = UInt(index)
            totalWidth += entity.type!.width
        }

        let type = Type(kind: .struct(s), flags: .none, width: totalWidth, location: .unknown)

        return Type.named(type, with: Entity.typeInfo)
    }()

    static func copy(_ type: Type) -> Type {
        let copy = Type(kind: type.kind, flags: type.flags, width: type.width, location: type.location)
        return copy
    }
}

extension Entity {
    
    static let typeInfo: Entity = {
        
        let entity = Entity(name: "TypeInfo", kind: .compiletime, type: .placeholder, owningScope: Scope.universal)
        entity.mangledName = "TypeInfo"

        return entity
    }()
}


// MARK: Builtin Procedures

var builtinProcedures: [Entity] = {

    typealias Short = (
        String, mangled: String,
        EntityExtra,
        params: [(String, Type)],
        returns: [Type],
        isVariadic: Bool
    )

    // These are later mapped into `[Entity]`
    let short: [Short] = [

        (
            "malloc", mangled: "malloc",
            EntityExtra(singleIrGen: IRGenerator.genForeign, callIrGen: nil),
            params: [("size", Type.i32)],
            returns: [Type.rawptr],
            isVariadic: false
        ),
        ( // NOTE(vdka): This will need to be different dependent on the type of the value.
            // if it is a dynamic Array then we need to free at a predefined offset from the pointer we are given.
            "free", mangled: "free",
            EntityExtra(singleIrGen: IRGenerator.genForeign, callIrGen: nil),
            params: [("ptr", Type.rawptr)],
            returns: [Type.void],
            isVariadic: false
        ),
        (
            "printf", mangled: "printf",
            EntityExtra(singleIrGen: IRGenerator.genForeign, callIrGen: nil),
            params: [("format", Type.pointer(to: Type.u8)), ("args", Type.any)],
            returns: [Type.void],
            isVariadic: true
        ),
        (
            "len", mangled: "len",
            EntityExtra(singleIrGen: nil, callIrGen: IRGenerator.genLenCall),
            params: [("array", Type.array(of: Type.any, with: 0))],
            returns: [Type.unconstrInteger],
            isVariadic: true
        ),
        (
            "sizeOfValue", mangled: "sizeOfValue",
            EntityExtra(singleIrGen: nil, callIrGen: IRGenerator.genSizeOfValueCall),
            params: [("val", Type.any)],
            returns: [Type.unconstrInteger],
            isVariadic: true
        ),
        (
            "memcpy", mangled: "memcpy",
            EntityExtra(singleIrGen: IRGenerator.genForeign, callIrGen: nil),
            params: [("dest", Type.rawptr), ("src", Type.rawptr), ("len", Type.i64)],
            returns: [Type.rawptr],
            isVariadic: false
        ),
    ]

    return short.map { (name, mangledName, extra, params, returns, isVariadic) in
        let entity = Entity(name: name, kind: .magic(extra), owningScope: Scope.universal)
        entity.mangledName = mangledName

        let procScope = Scope(parent: Scope.universal)
        entity.childScope = procScope
        
        let params = params.map { name, type in
            return Entity(name: name, kind: .magic(extra), type: type.instance, owningScope: procScope)
        }

        let returns = returns.map { type in
            return type.instance
        }

        entity.type = Type(kind: .proc(params: params, returns: returns, isVariadic: isVariadic), width: 0).instance

        return entity
    }
}()

struct EntityExtra {
    var singleIrGen: ((IRGenerator) -> (Entity) -> IRValue)?
    var callIrGen: ((IRGenerator) -> ([AstNode]) -> IRValue)?
}

extension IRGenerator {

    /// Will just emit a point to link to.
    func genForeign(_ entity: Entity) -> IRValue {
        return builder.addFunction(entity.mangledName!, type: canonicalize(entity.type!) as! FunctionType)
    }

    func genLenCall(_ args: [AstNode]) -> IRValue {

        let arg = args.first!

        let type = checker.info.types[arg]!

        guard case .array(_, let count) = type.kind else {
            panic(type)
        }

        return IntType.int64.constant(count)
    }

    func genSizeOfValueCall(_ args: [AstNode]) -> IRValue {

        let arg = args.first!

        let type = checker.info.types[arg]!

        return (type.width + 7) / 8
    }
}
