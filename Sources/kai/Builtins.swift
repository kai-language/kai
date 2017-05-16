
import LLVM

extension Scope {

    static let universal: Scope = {

        var s = Scope(parent: nil)

        // TODO(vdka): Create a stdtypes.kai file to refer to for location

        for type in Type.builtin {

            guard let location = type.location else {
                panic()
            }

            let e = Entity(name: type.description, location: location, kind: .compiletime, owningScope: s)
            e.type = type.type
            s.insert(e)
        }

        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(false), scope: s)

        var e: Entity
        e = Entity(name: "nil", location: .unknown, kind: .compiletime, owningScope: s)
        e.type = Type.unconstrNil
        s.insert(e)

        e = Entity(name: "_", location: .unknown, kind: .compiletime, owningScope: s)
        e.type = Type.any
        s.insert(e)

        return s
    }()
}

extension Type {

    static let builtin: [Type] = {

        // NOTE(vdka): Order is important later.

        let platformSize = UInt(MemoryLayout<Int>.size)
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

            ("rawptr", platformSize, 0, [.pointer]),

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


    var type: Type {
        let type = Type.copy(Type.typeInfo)
        type.kind = .type(self)
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

        //
        // By making TypeInfo exist in a dummy scope it will never be possible to refer directly to it.
        // Note that, at this point we cannot make the owning scope `.universal` because that scope 
        //   depends upon this type.
        // We will add `entity` to the `universal` scope and set owningScope later (in the init for `universal` scope)
        let dummyScope = Scope(parent: nil)
        let entity = Entity(name: "TypeInfo", kind: .compiletime, type: type, owningScope: dummyScope)

        return Type.named(entity)
    }()

    static func copy(_ type: Type) -> Type {
        let copy = Type(kind: type.kind, flags: type.flags, width: type.width, location: type.location)
        return copy
    }

//    static let typeInfo = Type(kind: .struct("TypeInfo"), flags: .none, width: 0, location: nil)
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
        )
    ]

    return short.map { (name, mangledName, extra, params, returns, isVariadic) in
        let entity = Entity(name: name, kind: .magic(extra), owningScope: Scope.universal)
        entity.mangledName = mangledName

        let procScope = Scope(parent: Scope.universal)
        entity.childScope = procScope
        
        let paramEntities = params.map({ Entity(name: $0.0, kind: .magic(extra), type: $0.1, owningScope: procScope) })
        entity.type = Type(kind: .proc(params: paramEntities, returns: returns, isVariadic: isVariadic), width: 0)

        print(entity.type!.description)

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

func declareBuiltinProcedures() {

    for entity in builtinProcedures {
        Scope.universal.insert(entity)
    }
}
