
/// Defines a type declaration
class TypeRecord {

    var kind: Kind
    var flags: Flag
    var source: AstNode
    var size: UInt

    enum Kind {
        case builtin
        case alias(of: TypeRecord)
    }

    struct Flag: OptionSet {
        var rawValue: UInt64
        init(rawValue: UInt64) { self.rawValue = rawValue }

        static let boolean        = Flag(rawValue: 0b00000001)
        static let integer        = Flag(rawValue: 0b00000010)
        static let unsigned       = Flag(rawValue: 0b00000100)
        static let float          = Flag(rawValue: 0b00001000)
        static let pointer        = Flag(rawValue: 0b00010000)
        static let string         = Flag(rawValue: 0b00100000)
        static let unconstrained  = Flag(rawValue: 0b01000000)

        static let none:     Flag = []
        static let numeric:  Flag = [.integer, .unsigned, .float]
        static let ordered:  Flag = [.numeric, .string, .pointer]
        static let constant: Flag = [.boolean, .numeric, .pointer, .string]
    }
}

enum std {
    private static let baseAddr = (#file).split("/").dropLast(3).append("stdlib").joined(separator: "/")

    static let types: String = "stdtypes.kai"
}

extension TypeRecord {

    // TODO(vdka): All these types could be mapped to the `stdtypes.kai` file

    static let builtinTypes: [TypeRecord] = {

        // Order is important later.
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

            // ("int", 0, 0), // TODO(vdka)
            // ("uint", 0, 0),
            ("string", 8, 0, .string), // FIXME(vdka): Currently strings are just pointers

            ("unconstrBool",    0, 0, [.unconstrained, .boolean]),
            ("unconstrInteger", 0, 0, [.unconstrained, .integer]),
            ("unconstrFloat",   0, 0, [.unconstrained, .float]),
            ("unconstrString",  0, 0, [.unconstrained, .string]),
            ("unconstrNil",     0, 0, [.unconstrained]),
        ]

        return short.map { (name, size, lineNumber, flags) in
            let location = SourceLocation(file: std.types, line: lineNumber, column: 0)

            return TypeRecord(kind: .builtin, flags: flags, source: .ident(name, location: location), size: size)
        }
    }()

    static let void = builtinTypes[0]
    static let bool = builtinTypes[1]

    static let i8   = builtinTypes[2]
    static let u8   = builtinTypes[3]
    static let i16  = builtinTypes[4]
    static let u16  = builtinTypes[5]
    static let i32  = builtinTypes[6]
    static let u32  = builtinTypes[7]
    static let i64  = builtinTypes[8]
    static let u64  = builtinTypes[9]

    static let f32  = builtinTypes[10]
    static let f64  = builtinTypes[11]

    static let string = builtinTypes[12]

    static let unconstrBool     = builtinTypes[13]
    static let unconstrInteger  = builtinTypes[14]
    static let unconstrFloat    = builtinTypes[15]
    static let unconstrString   = builtinTypes[16]
    static let unconstrNil      = builtinTypes[17]
}

/// Defines a type in which something can take
class Type {

    var kind: Kind
    unowned var record: TypeRecord

    enum Kind {
        case named(CheckedEntity)
        case typeInfo(TypeRecord)
        case proc(params: [Type], returns: [Type])
    }
}

class CheckedEntity {
    var name: String
    var kind: Kind
    var flags: Flag
    var type: Type

    var childScope: Scope?
    var mangledName: String

    enum Kind {
        case runtime
        case compiletime
    }

    struct Flag: OptionSet {
        let rawValue: UInt8

        static let none       = Flag(rawValue: 0b00000000)
        static let parameter  = Flag(rawValue: 0b00000001)
    }
}

class Entity {
    var kind: Kind
    var flags: Flag
    var name: String
    var location: SourceLocation
    unowned var scope: Scope

    /// Set in the checker
    var type: Type? = nil
    var identifier: AstNode?

    enum Kind {
        case invalid
        case compiletime
        case runtime
        case typeName
        case procedure // (isForeign (foreignDetails), tags, overload: OverloadKind)
        case builtin
        case importName  //path, name: String, scope: Scope, used: Bool)
        case libraryName // (path, name: String, used: Bool)
        case `nil`
    }

    static func declareBuiltinConstant(name: String, value: ExactValue, scope: Scope) {
        var type: Type
        switch value {
        case .invalid:
            type = .invalid

        case .bool(_):
            type = .unconstrBoolean

        case .float(_):
            type = .unconstrFloat

        case .integer(_):
            type = .unconstrInteger

        case .string(_):
            type = .unconstrString
        }

        let e = Entity(kind: .compileTime(value), name: name, location: .unknown, scope: scope, identifier: nil)
        e.type = type

        scope.insert(e)
    }
}

struct Library {
    var importPath: String
    var fullpath: String
}

indirect enum CheckedAstNode {

    case invalid(AstNode)

    case file(name: String, Scope)

    case scope(Scope)
    case entityUse(CheckedEntity)
    case entityDecl(CheckedEntity)

    case litInteger(Int64)
    case litFloat(Double)
    case litString(String)
    case litProc(params: [CheckedEntity], type: Type, body: Scope)
    case foreignProc(params: [CheckedEntity], type: Type, sourceLib: Library, symbolName: String)

    case exprCall(receiver: CheckedAstNode, args: [CheckedAstNode])
    case exprUnary(UnaryOperator, expr: CheckedAstNode)
    case exprBinary(BinaryOperator, lhs: CheckedAstNode, rhs: CheckedAstNode)
    case exprTernary(cond: CheckedAstNode, CheckedAstNode, CheckedAstNode)

    case stmtAssign(AssignOperator, lhs: [CheckedAstNode], rhs: [CheckedAstNode])

    case stmtIf(cond: CheckedAstNode, body: CheckedAstNode, CheckedAstNode?)
    case stmtReturn([CheckedAstNode])
    case stmtCase(list: [CheckedAstNode], statements: Scope)
    case stmtDefer(CheckedAstNode)
    case stmtBreak
    case stmtContinue
    case stmtFallthrough
}

class Scope {
    weak var parent: Scope?
    var children: [Scope] = []
    var imported: [Scope] = []
    var shared: [Scope] = []

    var elements: [String: Entity] = [:]
    var isProc: Bool = false

    /// Only set if scope is file
    var file: ASTFile? = nil
    var isFile: Bool { return file != nil }

    init(parent: Scope?) {
        self.parent = parent
    }

    static var universal: Scope = {

        var s = Scope(parent: nil)

        // TODO(vdka): Create a stdtypes.kai file to refer to for location

        for type in Type.allBasicTypes {
            guard case .basic(let basicType) = type.kind else {
                panic()
            }

            let e = Entity(kind: .builtin, name: basicType.name, location: .unknown, flags: [], scope: s, identifier: nil)
            e.type = type
            s.insert(e)

        }

        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(true), scope: s)

        let e = Entity(kind: .nil, name: "nil", location: .unknown, scope: s, identifier: nil)
        e.type = Type.unconstrNil
        s.insert(e)

        return s
    }()

    init(parent: Scope?) {
        self.parent = parent
    }
}

extension Scope {

    /// - Returns: Entity replaced by this insertion.
    @discardableResult
    func insert(_ entity: Entity) -> Entity? {
        defer { elements[entity.name] = entity }
        return elements[entity.name]
    }

    func lookup(_ name: String) -> Entity? {

        if let entity = elements[name] {
            return entity
        } else {
            return parent?.lookup(name)
        }
    }
}

class DeclInfo {

    unowned var scope: Scope

    /// Each entity represents a reference to the original decl `x := 5; x = x + 8` would have a DeclInfo for `x` with 3 entities
    var entities: [Entity]

    var typeExpr: AstNode?
    var initExpr: AstNode?

    init(scope: Scope, entities: [Entity] = [], typeExpr: AstNode? = nil, initExpr: AstNode? = nil) {
        self.scope = scope
        self.entities = entities
        self.typeExpr = typeExpr
        self.initExpr = initExpr
    }
}

struct DelayedDecl {
    unowned var parent: Scope
    var decl: AstNode
}

struct Checker {
    var parser: Parser
    var currentFile: ASTFile
    var info: Info
    var globalScope: Scope
    var context: Context

    var procStack: [Type] = []

    var delayedImports:  [DelayedDecl] = []
    var delayedLibaries: [DelayedDecl] = []

    /// The entity corresponding to the global 'main' symbol
    var main: Entity?

    /*
	Array(ProcedureInfo)   procs; // NOTE(bill): Procedures to check
	Array(DelayedDecl)     delayed_imports;
	Array(DelayedDecl)     delayed_foreign_libraries;

	Array(Type *)          proc_stack;
	bool                   done_preload;
    */

    init(parser: Parser) {
        self.parser = parser

        currentFile = parser.files.first!
        info = Info()

        globalScope = Scope(parent: .universal)
        context = Context(scope: globalScope)
    }

    struct Info {
        var types:       [AstNode: Type]    = [:]
        var definitions: [AstNode: Entity]  = [:]
        var uses:        [AstNode: Entity]  = [:]
        var scopes:      [AstNode: Scope]   = [:]
        var untyped:     [AstNode: Entity]  = [:]
        var entities:    [Entity: DeclInfo] = [:]
    }

    /*
    // CheckerInfo stores all the symbol information for a type-checked program
    typedef struct CheckerInfo {
        MapTypeAndValue      types;           // Key: AstNode * | Expression -> Type (and value)
        MapEntity            definitions;     // Key: AstNode * | Identifier -> Entity
        MapEntity            uses;            // Key: AstNode * | Identifier -> Entity
        MapScope             scopes;          // Key: AstNode * | Node       -> Scope
        MapExprInfo          untyped;         // Key: AstNode * | Expression -> ExprInfo
        MapDeclInfo          entities;        // Key: Entity *
        MapEntity            foreigns;        // Key: String
        MapAstFile           files;           // Key: String (full path)
        MapIsize             type_info_map;   // Key: Type *
        isize                type_info_count;
    } CheckerInfo;
    */

    struct Context {
        var scope: Scope
        var fileScope: Scope? = nil
        var decl: DeclInfo?   = nil
        var inDefer: Bool     = false
        var procName: String? = nil
        var typeHint: Type?   = nil

        init(scope: Scope) {
            self.scope = scope

            fileScope = nil
            decl      = nil
            inDefer   = false
            procName  = nil
            typeHint  = nil
        }
    }
}


// MARK: Checker functions

extension Checker {

    mutating func checkParsedFiles() {

        var fileScopes: [String: Scope] = [:]

        for file in parser.files {
            let scope = Scope(parent: globalScope)
            scope.isGlobal = true
            scope.isFile = true
            scope.file = file
            scope.isInit = true // TODO(vdka): Is this the first scope we parsed? (The file the compiler was called upon)

            if scope.isGlobal {
                globalScope.shared.append(scope)
            }

            file.scope = scope
            fileScopes[file.fullpath] = scope
        }

        for file in parser.files {
            let prevContext = context

            setCurrentFile(file)

            collectEntities(file.nodes, isFileScope: true)

            context = prevContext
        }

        importEntities(&fileScopes)

        checkAllGlobalEntities()
    }

    mutating func collectEntities(_ nodes: [AstNode], isFileScope: Bool) {
        if isFileScope {
            assert(context.scope.isFile)
        } else {
            assert(!context.scope.isFile)
        }

        for node in nodes {

            guard node.isDecl else {
                // NOTE(vdka): For now only declarations are valid at file scope.
                // TODO(vdka): Report an error
                reportError("Currently only declarations are valid at file scope", at: node)
                continue
            }

            switch node {
            case .declValue(isRuntime: let isRuntime, names: let names, type: let type, values: let values, _):
                guard !isRuntime else {
                    reportError("Runtime declarations not allowed at file scope (for now)", at: node)
                    return
                }
                for (index, name) in names.enumerated() {
                    guard name.isIdent else {
                        reportError("A declaration's name must be an identifier", at: name)
                        continue
                    }

                    let value = values[safe: index].map({ $0.unparenExpr() })

                    let declInfo = DeclInfo(scope: context.scope)
                    var entity: Entity
                    if let value = value, value.isType {
                        entity = Entity(kind: .typeName, name: name.identifier, scope: declInfo.scope, identifier: name)
                        declInfo.typeExpr = value
                        declInfo.initExpr = value
                    } else if let value = value, case .litProc = value {

                        // TODO(vdka): Some validation around explicit typing for procLits?
                        /*
                         someProc : (int) -> void : (n: int) -> void { /* ... */ }
                         */

                        entity = Entity(kind: .procedure, name: name.identifier, scope: declInfo.scope, identifier: name)
                        declInfo.initExpr = value
                    } else {
                        entity = Entity(kind: .compileTime(.invalid), name: name.identifier, scope: declInfo.scope, identifier: name)
                        declInfo.typeExpr = type
                        declInfo.initExpr = value
                    }

                    declInfo.entities.append(entity)

                    addEntity(to: entity.scope, identifier: name, entity)
                    info.entities[entity] = declInfo
                }
                checkArityMatch(node)

            case .declImport, .declLibrary:
                if !context.scope.isFile {
                    reportError("#import and #library directives are only valid at file scope", at: node)
                }

                let decl = DelayedDecl(parent: context.scope, decl: node)
                delayedImports.append(decl)

            default:
                fatalError()
            }
        }
    }

    mutating func importEntities(_ fileScopes: inout [String: Scope]) {

        for imp in delayedImports {
            guard case .declImport(let path, let fullpathOpt, let importName, _) = imp.decl else {
                preconditionFailure()
            }

            guard let fullpath = fullpathOpt else {
                reportError("Failed to import file: \(path.value)", at: path)
                return
            }

            let parentScope = imp.parent

            assert(parentScope.isFile)

            guard parentScope.hasBeenImported else {
                continue
            }

            // TODO(vdka): Fail gracefully
            let scope = fileScopes[fullpath]!

            let previouslyAdded = parentScope.imported.contains(where: { $0 === scope })

            if !previouslyAdded {
                parentScope.imported.append(scope)
            } else {
                reportError("Multiple imports for a single file in current scope", at: imp.decl)
            }

            scope.hasBeenImported = true

            if importName?.identifier == "." {
                // NOTE(vdka): add imported entities into this files scope.

                for entity in scope.elements.values {
                    if entity.scope === parentScope {
                        continue
                    }
                    if !entity.isExported {
                        continue
                    }
                    addEntity(to: scope, identifier: nil, entity)
                }
            } else {
                let importName = Checker.pathToEntityName(fullpath)
                if importName == "_" {
                    reportError("File name cannot be automatically assigned an identifier name, you will have to manually specify one.", at: path)
                } else {
                    let entity = Entity(kind: .importName, name: importName, scope: scope, identifier: path)
                    addEntity(to: parentScope, identifier: nil, entity)
                }
            }
        }

        for _ in delayedLibaries {
            unimplemented("Foreign libraries") // TODO(vdka): This should be super easy.
        }
    }

    mutating func checkAllGlobalEntities() {

        for (e, d) in info.entities {

            // of course the declaration can be in a scope that is beyond the use scope as in:
            // `tau :: 6.18; circumference :: (r: f64) -> f64 { return tau * r }`
            if d.scope !== e.scope {
                continue
            }

            setCurrentFile(d.scope.file!)

            guard d.scope.hasBeenImported || d.scope.isInit else {
                // How did we even get into a file that wasn't imported?
                continue
            }

            if case .procedure = e.kind, e.name == "main" {
                // TODO(vdka): Ensure we're in the initial file scope
                // guard e.scope.isInit else { continue with error }
                guard self.main == nil else {
                    reportError("Duplicate definition of symbol 'main'", at: e.location)
                    continue
                }

                self.main = e
            }

            fillType(d)
        }
    }

    mutating func setCurrentFile(_ file: ASTFile) {
        self.currentFile = file
        self.context.decl = file.declInfo
        self.context.scope = file.scope!
        self.context.fileScope = file.scope!
    }

    @discardableResult
    mutating func addEntity(to scope: Scope, identifier: AstNode?, _ entity: Entity) -> Bool {

        if let conflict = scope.insert(entity) {

            let msg = "Redeclaration of \(entity.name) in this scope\n" +
                      "Previous declaration at \(conflict.location)"

            reportError(msg, at: entity.location)
            return false
        }

        // Set the entity for the declaring node.
        if let identifier = identifier {
            info.definitions[identifier] = entity
        }

        return true
    }

    @discardableResult
    mutating func checkArityMatch(_ node: AstNode) -> Bool {

        if case .declValue(_, let names, let type, let values, _) = node {
            if values.isEmpty && type == nil {
                reportError("Missing type or initial expression", at: node)
                return false
            } else if names.count < values.count {
                reportError("Arity mismatch, excess expressions on rhs", at: values[names.count])
                return false
            } else if names.count > values.count && values.count != 1 {
                reportError("Arity mismatch, missing expressions for ident", at: names[values.count])
                return false
            }
        }

        return true
    }
}


// MARK: Actual Checking

extension Checker {

    @discardableResult
    mutating func fillType(_ d: DeclInfo) -> Type {

        var type: Type
        switch (d.typeExpr, d.initExpr) {
        case (nil, let initExpr?):
            switch initExpr {
            case .litInteger:
                type = .unconstrInteger

            case .litFloat:
                type = .unconstrFloat

            case .litString:
                type = .unconstrString

            case .litProc(let typeExpr, let body, _):
                guard case .typeProc(let params, let results, _) = typeExpr else {
                    panic()
                }

                var paramTypes:  [Type] = []
                var returnTypes: [Type] = []

                switch body {
                case .stmtBlock:
                    let scope = Scope(parent: context.scope)

                    /*
                     Fill types for each parameter
                     There are only 3 valid cases:
                        - `(int, int) -> void` has no declValues (only types) FIXME(vdka): Could (should)? make this illegal
                        - `(x: int, y: int) -> void` has decl values
                        - `(x: int, y: int) -> (x: int, y: int)` would also be valid, however for results we only care about the types
                    */
                    for param in params {
                        switch param {
                        case .declValue(_, let names, let type, let values, _):

                            assert(names.count == 1, "Parser should explode parameters so each decl has exactly 1 value")
                            assert(type != nil)

                            guard let ident = names.first, let type = type else {
                                panic()
                            }
                            if !values.isEmpty {
                                unimplemented("Default procedure argument values")
                            }

                            let entity = Entity(kind: Entity.Kind.runtime, name: ident.identifier, location: ident.startLocation, flags: .param, scope: scope, identifier: ident)
                            let paramDecl = DeclInfo(scope: scope, entities: [entity], typeExpr: type, initExpr: nil)
                            let paramType = fillType(paramDecl)
                            paramTypes.append(paramType)

                        default:
                            let paramType = lookupType(param)
                            paramTypes.append(paramType)
                        }
                    }

                    for result in results {
                        switch result {
                        case .declValue(_, let names, let type, let values, _):
                            // NOTE(vdka): In the results, we don't care about the identifier name. Just the type.

                            assert(names.count == 1, "Parser should explode results so each decl has exactly 1 value")
                            assert(type != nil)

                            guard let type = type else {
                                panic()
                            }
                            if !values.isEmpty {
                                unimplemented("Default procedure argument values")
                            }

                            let returnType = lookupType(type)
                            returnTypes.append(returnType)

                        default:
                            // If it is not a `declValue` it *must* be a type
                            let returnType = lookupType(result)
                            returnTypes.append(returnType)
                        }
                    }

                    type = Type(kind: .proc(params: paramTypes, returns: returnTypes, isVariadic: false))

                case .directive:
                    unimplemented("Foreign body functions")

                default:
                    panic()
                }

            default:
                reportError("Type cannot be inferred from \(initExpr)", at: initExpr)
                return Type.invalid
            }

        default:
            // FIXME(vdka): Why is this a print not anything else?
            print("failed filling declinfo \(d)")
            return Type.invalid
        }

        for e in d.entities {
            e.type = type
        }

        return type
    }

    func lookupType(_ n: AstNode) -> Type {

        switch n {
        case .ident(let ident, _):

            guard let entity = context.scope.lookup(ident) else {
                reportError("Undeclared entity '\(ident)'", at: n)
              return Type.invalid
            }

            switch entity.kind {
            case .typeName, .builtin:
                return entity.type!

            default:
                reportError("Entity '\(ident)' cannot be used as type", at: n)
                return Type.invalid
            }

        case .exprSelector(let receiver, let member, _):

            // TODO(vdka): Determine (define) the realm of possibility in terms of what can be a node representing a type
            guard case .ident(let receiverIdent, _) = receiver else {
                reportError("'\(n)' cannot be used as a type", at: n)
                return Type.invalid
            }
            guard case .ident(let memberIdent, _) = member else {
                reportError("'\(n)' cannot be used as a type", at: n)
                return Type.invalid
            }
            guard let receiverEntity = context.scope.lookup(receiverIdent) else {
                reportError("Undeclared entity '\(receiverIdent)'", at: receiver)
                return Type.invalid
            }
            _ = memberIdent
            /* TODO(vdka):
             In the receiverEntities scope lookup the child entity.
             Determine how to access the scope the receiver would have to create.
             In this scenario the recvr should have a child scope.
            */
            _ = receiverEntity
            unimplemented("Child types")

        default:
            reportError("'\(n)' cannot be used as a type", at: n)
            return Type.invalid
        }
    }
}

extension Checker {

    static func pathToEntityName(_ path: String) -> String {
        precondition(!path.isEmpty)

        let filename = String(path.unicodeScalars
            .split(separator: "/").last!
            .split(separator: ".").first!)

        if isValidIdentifier(filename) {
            return filename
        } else {
            return "_"
        }
    }

    static func isValidIdentifier(_ str: String) -> Bool {
        guard !str.isEmpty else {
            return false
        }

        if !identChars.contains(str.unicodeScalars.first!) {
            return false
        }

        return str.unicodeScalars.dropFirst()
            .contains(where: { identChars.contains($0) || digits.contains($0) })
    }
}
