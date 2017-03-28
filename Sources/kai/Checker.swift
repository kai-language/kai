/// Defines a type in which something can take
class Type: CustomStringConvertible {

    var kind: Kind
    var flags: Flag
    var size: UInt
    var location: SourceLocation?

    init(kind: Kind, flags: Flag, size: UInt, location: SourceLocation?) {
        self.kind = kind
        self.flags = flags
        self.size = size
        self.location = location
    }

    enum Kind {
        case named(String)
        case alias(String, Type)
        case proc(params: [Entity], returns: [Type])
        case `struct`(String)
    }

    struct Flag: OptionSet {
        var rawValue: UInt64
        init(rawValue: UInt64) { self.rawValue = rawValue }

        static let boolean        = Flag(rawValue: 0b00000001)
        static let integer        = Flag(rawValue: 0b00000010)
        static let unsigned       = Flag(rawValue: 0b00000110)
        static let float          = Flag(rawValue: 0b00001000)
        static let pointer        = Flag(rawValue: 0b00010000)
        static let string         = Flag(rawValue: 0b00100000)
        static let unconstrained  = Flag(rawValue: 0b01000000)

        static let none:         Flag = []
        static let numeric:      Flag = [.integer, .unsigned, .float]
        static let ordered:      Flag = [.numeric, .string, .pointer]
        static let booleanesque: Flag = [.numeric, .boolean]
    }

    var description: String {
        switch kind {
        case .named(let name):
            return name

        case .alias(let name, let type):
            return name + " aka " + type.description

        case .proc(let params, let returns):
            return "(" + params.map({ $0.type!.description }).joined(separator: ", ") + ") -> " + returns.map({ $0.description }).joined(separator: ", ")

        case .struct(let name):
            return name
        }
    }

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

            ("<invalid>", 0, 0, .none),
        ]

        return short.map { (name, size, lineNumber, flags) in
            let location = SourceLocation(line: lineNumber, column: 0, file: std.types)

            return Type(kind: .named(name), flags: flags, size: size, location: location)
        }
    }()

    static let typeInfo = Type(kind: .struct("TypeInfo"), flags: .none, size: 0, location: nil)

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

    static let invalid = builtin[20]
}

enum ExactValue {
    case invalid
    case bool(Bool)
    case string(String)
    case integer(Int64)
    case float(Double)
    case type
}

class Entity: PointerHashable {
    var name: String
    var location: SourceLocation
    var kind: Kind
    var flags: Flag = []
    unowned var owningScope: Scope

    // NOTE(vdka): All filled in by the checker

    var type: Type?

    var mangledName: String?

    var childScope: Scope?
    var value: ExactValue?
    
    init(name: String, location: SourceLocation, kind: Kind, owningScope: Scope) {
        self.name = name
        self.location = location
        self.kind = kind
        self.owningScope = owningScope
    }

    init(identifier: AstNode, kind: Kind, owningScope: Scope) {
        guard case .ident(let name, let location) = identifier else {
            panic()
        }
        self.name = name
        self.location = location.lowerBound
        self.kind = kind
        self.owningScope = owningScope
    }

    enum Kind {
        case runtime
        case compiletime
        case type(Type)

        case importName  //path, name: String, scope: Scope, used: Bool)
        case libraryName // (path, name: String, used: Bool)
        case invalid
    }

    struct Flag: OptionSet {
        var rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let none = Flag(rawValue: 0b00000000)
        static let used = Flag(rawValue: 0b00000001)
    }

    static func declareBuiltinConstant(name: String, value: ExactValue, scope: Scope) {
        var type: Type
        switch value {
        case .invalid, .type:
            panic()

        case .bool(_):
            type = .unconstrBool

        case .float(_):
            type = .unconstrFloat

        case .integer(_):
            type = .unconstrInteger

        case .string(_):
            type = .unconstrString
        }

        let e = Entity(name: name, location: .unknown, kind: .compiletime, owningScope: scope)
        e.type = type
        e.value = value

        scope.insert(e)
    }
}

struct Library {
    var importPath: String
    var fullpath: String
}

class Scope: PointerHashable {
    weak var parent: Scope?
    var imported: [Scope] = []
    var shared: [Scope] = []

    var elements: [String: Entity] = [:]
    var isProc: Bool = false
    var isMainFile: Bool = false

    /// Only set if scope is file
    var file: ASTFile? = nil
    var isFile: Bool { return file != nil }

    init(parent: Scope?) {
        self.parent = parent
    }

    static var universal: Scope = {

        var s = Scope(parent: nil)

        // TODO(vdka): Create a stdtypes.kai file to refer to for location

        for type in Type.builtin {

            guard let location = type.location else {
                panic()
            }

            let e = Entity(name: type.description, location: location, kind: .type(type), owningScope: s)
            e.type = Type.typeInfo
            s.insert(e)
        }

        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(false), scope: s)

        let e = Entity(name: "nil", location: .unknown, kind: .compiletime, owningScope: s)
        e.type = Type.unconstrNil
        s.insert(e)

        return s
    }()
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

class ProcInfo {
    unowned var owningScope: Scope
    var decl: DeclInfo?
    var type: Type
    var node: AstNode // AstNode.litProc

    init(owningScope: Scope, decl: DeclInfo?, type: Type, node: AstNode) {
        self.owningScope = owningScope
        self.decl = decl
        self.type = type
        self.node = node
    }
}

class DeclInfo: PointerHashable {

    unowned var scope: Scope

    /// Each entity represents a reference to the original decl `x := 5; x = x + 8` would have a DeclInfo for `x` with 3 entities
    var entities:  [Entity]
    var typeExpr:   AstNode?
    var initExprs: [AstNode]

    init(scope: Scope, entities: [Entity] = [], typeExpr: AstNode? = nil, initExprs: [AstNode] = []) {
        self.scope = scope
        self.entities = entities
        self.typeExpr = typeExpr
        self.initExprs = initExprs
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

    /*
     // ProcedureInfo stores the information needed for checking a procedure
     typedef struct ProcedureInfo {
         AstFile * file;
         Token     token;
         DeclInfo *decl;
         Type *    type; // Type_Procedure
         AstNode * body; // AstNode_BlockStmt
         u32       tags;
     } ProcedureInfo;

    */

    var procs: [ProcInfo] = []
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
        var entities:    [Entity: DeclInfo]  = [:]
        var definitions: [AstNode: Entity]   = [:] // Key: AstNode.ident
        var decls:       [AstNode: DeclInfo] = [:] // Key: AstNode.declValue
        var types:       [AstNode: Type]     = [:] // Key: AstNode.expr*
        var uses:        [AstNode: Entity]   = [:] // Key: AstNode.ident
        var scopes:      [AstNode: Scope]    = [:] // Key: Any AstNode
    }

    struct Context {
        var scope: Scope
        var inDefer: Bool = false

        init(scope: Scope) {
            self.scope = scope

            inDefer   = false
        }
    }
}
















// MARK: Checker functions

extension Checker {

    mutating func checkParsedFiles() {

        var fileScopes: [String: Scope] = [:]

        for (index, file) in parser.files.enumerated() {

            let scope = Scope(parent: globalScope)
            scope.file = parser.files[index]

            // globalScope.shared.append(scope)

            if index == parser.files.startIndex {
                scope.isMainFile = true
            }

            file.scope = scope
            fileScopes[file.fullpath] = scope
        }

        for file in parser.files {
            let prevContext = context

            setCurrentFile(file)

            // Create entity records for things in file scopes
            collectEntities(file.nodes)

            context = prevContext

            /* If you want to print all entities found in said file
             print("entities found in file \(file.path): ")
             print(Array(file.scope!.elements.keys!))
            */
        }

        importEntities(&fileScopes)

        for scope in fileScopes.values {
            checkEntities(in: scope)
        }

        for pi in procs {
            let prevContext = context

            checkProcBody(pi)

            context = prevContext
        }

        // For now we should require compiler invocation on a single file.
        let mainFile = fileScopes.first(where: { $0.value.isMainFile })!

        main = mainFile.value.lookup("main")
        if main == nil {
            reportError("Undefined entry point 'main'", at: SourceLocation(line: 1, column: 1, file: mainFile.key))
        }
    }

    /// - Precondition: node.isDecl
    @discardableResult
    mutating func collectEntities(_ node: AstNode) -> [Entity] {
        precondition(node.isDecl)

        switch node {
        case .declValue(let isRuntime, let names, let type, let values, _):

            let declInfo = DeclInfo(scope: context.scope)
            declInfo.typeExpr = type

            for (index, name) in names.enumerated() {

                guard name.isIdent else {
                    reportError("A declaration's name must be an identifier", at: name)
                    continue
                }

                let value = values[safe: index].map(unparenExpr)

                var entity: Entity
                if let value = value {
                    entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                    declInfo.initExprs.append(value)
                } else {
                    assert(values.isEmpty)
                    entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                }

                declInfo.entities.append(entity)

                addEntity(to: declInfo.scope, entity)

                // TODO(vdka): Check entities are not used in their own intialization.
                info.entities[entity] = declInfo
                info.definitions[name] = entity
            }
            checkArityMatch(node)

            info.decls[node] = declInfo

            return declInfo.entities

        case .declLibrary(let libPathNode, _, let libNameNode, _):

            guard case .litString = libPathNode else {
                panic()
            }

            guard case .ident = libNameNode! else {
                panic()
            }

            let e = Entity(identifier: libNameNode!, kind: .libraryName, owningScope: context.scope)
            addEntity(to: context.scope, e)

            return [e]

            // TODO(vdka): Set any flags for the linking phase to use

        case .declImport:
            if !context.scope.isFile {
                reportError("#import directives are only valid at file scope", at: node)
            }

            let decl = DelayedDecl(parent: context.scope, decl: node)
            delayedImports.append(decl)
            return []

        default:
            // The node doesn't declare anything
            assert(!context.scope.isFile)
            return []
        }
    }

    mutating func collectEntities(_ nodes: [AstNode]) {

        for node in nodes {
            guard node.isDecl else {
                if context.scope.isFile {
                    reportError("Currently only declarations are valid at file scope", at: node)
                }
                continue
            }

            collectEntities(node)
        }
    }

    mutating func importEntities(_ fileScopes: inout [String: Scope]) {

        for imp in delayedImports {

            guard case .declImport(let path, let fullpathOpt, let importName, _) = imp.decl else {
                panic()
            }

            if case .ident(".", _)? = importName {
                return
            }

            guard let fullpath = fullpathOpt else {
                reportError("Failed to import file: \(path.value)", at: path)
                return
            }

            let parentScope = imp.parent

            assert(parentScope.isFile)

            let scope = fileScopes[fullpath]!

            let previouslyAdded = parentScope.imported.contains(where: { $0 === scope })

            if !previouslyAdded {
                parentScope.imported.append(scope)
            } else {
                reportError("Multiple imports for a single file in current scope", at: imp.decl)
            }

            // import entities into current scope
            if importName?.identifier == "." {
                // NOTE(vdka): add imported entities into this files scope.

                // FIXME(vdka): THIS IS A BUG. IT LOOKS LIKE YOU ARE ADDING ENTITIES TO THE FILE FROM WHICH THEY RESIDE.
                for entity in scope.elements.values {
                    addEntity(to: scope, entity)
                }
            } else {
                let (importName, error) = Checker.pathToEntityName(fullpath)
                if error {
                    reportError("File name cannot be automatically assigned an identifier name, you will have to manually specify one.", at: path)
                } else {
                    let e = Entity(name: importName, location: path.startLocation, kind: .importName, owningScope: scope)
                    e.childScope = scope
                    addEntity(to: parentScope, e)
                }
            }
        }
    }

    mutating func checkEntity(_ e: Entity) {
        switch e.kind {
        case .libraryName, .importName:
            return

        default:
            guard let decl = info.entities[e] else {
                panic()
            }

            fillType(decl)
        }
    }

    mutating func checkEntities(in scope: Scope) {

        let prevContext = context
        context.scope = scope

        for e in scope.elements.values {
            checkEntity(e)
        }

        context = prevContext
    }

    mutating func setCurrentFile(_ file: ASTFile) {
        self.currentFile = file
        self.context.scope = file.scope!
    }

    @discardableResult
    mutating func addEntity(to scope: Scope, _ entity: Entity) -> Bool {

        if let conflict = scope.insert(entity) {

            let msg = "Redeclaration of \(entity.name) in this scope\n" +
                      "Previous declaration at \(conflict.location)"

            reportError(msg, at: entity.location)
            return false
        }

        return true
    }

    @discardableResult
    mutating func addEntityUse(_ ident: AstNode, _ entity: Entity) {
        assert(ident.isIdent)
        info.uses[ident] = entity
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

    /// - Warning: You must queue the procedure to have it's body checked later.
    /// - Returns: The type for the procedure
    mutating func checkProcLitType(_ node: AstNode) -> Type {
        guard case .litProc(let typeNode, _, _) = node else {
            panic()
        }

        guard case .typeProc(let params, let results, _) = typeNode else {
            panic()
        }


        var paramEntities: [Entity] = []
        var returnTypes:   [Type]   = []

        // NOTE(vdka): Ensure that this is the scope used when checking the body of the procedure later
        let scope = Scope(parent: context.scope)
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


                let e = Entity(identifier: ident, kind: .runtime, owningScope: scope)
                let paramDecl = DeclInfo(scope: scope, entities: [e], typeExpr: type, initExprs: [])

                fillType(paramDecl)

                paramEntities.append(e)

                info.definitions[ident] = e
                info.entities[e] = paramDecl

            default:
                // TODO(vdka): Validate that the procedure has a foreign body if arg names are omitted.

                let type = lookupType(param)

                let e = Entity(name: "_", location: param.startLocation, kind: .runtime, owningScope: scope)
                e.type = type

                paramEntities.append(e)
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

        let type = Type(kind: .proc(params: paramEntities, returns: returnTypes), flags: .none, size: 0, location: nil)

        return type
    }

    func canImplicitlyConvert(_ a: Type, to b: Type) -> Bool {
        if a === b {
            return true
        }

        if a.flags.contains(.unconstrained) {

            if a.flags.contains(.float) && b.flags.contains(.float) {
//            if a.flags.contains(.float) && b.flags.contains(.float) || b.flags.contains(.integer) {
                // `x: f32 = integerValue` | `y: f32 = floatValue`
                return true
            }
            if a.flags.contains(.integer) && b.flags.contains(.float) {
                // implicitely upcast an integer into a float is fine.
                return true
            }
            if a.flags.contains(.integer) && b.flags.contains(.integer) {
                // Currently we support converting any integer to any other integer implicitely
                return true
            }
            if !Type.Flag.numeric.union(a.flags).isEmpty && b.flags.contains(.boolean) {
                // Any numeric type can be cast to booleans
                return true
            }
            if a.flags.contains(.boolean) && b.flags.contains(.boolean) {
                return true
            }
            if a.flags.contains(.string) && b.flags.contains(.string) {
                return true
            }

        } else if Type.Flag.numeric.contains(a.flags) && b.flags.contains(.boolean) {
            // Numeric types can be converted to booleans through truncation
            return true
        }
        return false
    }

    @discardableResult
    mutating func fillType(_ d: DeclInfo) {

        let explicitType = d.typeExpr.map(lookupType) // TODO(vdka): Check if the type is invalid; if so then we don't need to check the rvalue

        for (i, e) in d.entities.enumerated() {
            let initExpr = d.initExprs[safe: i]
            let rvalueType = initExpr.map({ checkExpr($0) })

            if let rvalueType = rvalueType, let explicitType = explicitType {

                // if there is an explicit type ensure we do not conflict with it
                if !canImplicitlyConvert(rvalueType, to: explicitType) {
                    reportError("Cannot implicitly convert type '\(rvalueType)' to type '\(explicitType)'", at: d.typeExpr!)
                    e.type = Type.invalid
                    continue
                }

                e.type = explicitType

                attemptLiteralConstraint(initExpr!, to: explicitType)

            } else if let explicitType = explicitType {

                e.type = explicitType
            } else if let rvalueType = rvalueType {

                e.type = rvalueType
            } else {
                panic() // NOTE(vdka): No explicit type or rvalue
            }
        }

        // Provide the procInfo that *must* have been created with the decl it was created as part of
        // TODO(vdka): Multiple litProcs as rvalues? 
        // `add, sub :: (l, r: int) -> int { return l + r }, (l, r: int) -> int { return l - r }`
        if case .litProc(_, let body, _)? = d.initExprs.first, body.isStmt {
            procs.last!.decl = d
        }
    }

    /// Use this when you expect the node you pass in to be a type
    func lookupType(_ n: AstNode) -> Type {
        if let type = info.types[n] {
            return type
        }

        switch n {
        case .ident(let ident, _):

            guard let entity = context.scope.lookup(ident) else {
                reportError("Undeclared entity '\(ident)'", at: n)
                return Type.invalid
            }

            switch entity.kind {
            case .type(let type):
                return type

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

    mutating func checkAssign(_ node: AstNode) {
        guard case .stmtAssign(let op, let lhs, let rhs, _) = node else {
            panic()
        }
        unimplemented("Complex assignment", if: op != "=")

        guard lhs.count == rhs.count else {
            reportError("assignment count mismatch: '\(lhs.count) = \(rhs.count)'", at: node)
            return
        }

        for (lvalue, rvalue) in zip(lhs, rhs) {
            let rhsType = checkExpr(rvalue)
            let lhsType = checkExpr(lvalue)

            guard canImplicitlyConvert(rhsType, to: lhsType) else {
                if rvalue.isLit {
                    attemptLiteralConstraint(rvalue, to: lhsType)
                }
                reportError("Cannot use \(rvalue.value) (type \(rhsType)) as type \(lhsType) in assignment", at: rvalue)
                return
            }
        }
    }

    mutating func checkStmt(_ node: AstNode) {

        switch node {
        case .declValue, .declImport, .declLibrary:
            let entities = collectEntities(node)
            for e in entities {
                checkEntity(e)
            }

        case _ where node.isExpr:
            checkExpr(node)

        case .stmtBlock(let stmts, _):
            let prevContext = context

            let s = Scope(parent: context.scope)
            info.scopes[node] = s
            context.scope = s
            checkStmts(stmts)

            context = prevContext

        case .stmtAssign:
            checkAssign(node)

        case .stmtReturn(let vals, _):

            for val in vals {
                checkExpr(val)
            }
            guard context.scope.isProc else {
                reportError("'return' is not valid in this scope", at: node)
                return
            }

        case .stmtIf(let cond, let body, let elseExpr, _):

            let condType = checkExpr(cond)
            guard canImplicitlyConvert(condType, to: Type.bool) else {
                reportError("Cannot use expression as boolean value", at: cond)
                return
            }

            checkStmt(body)

            if let elseExpr = elseExpr {
                checkStmt(elseExpr)
            }

        case .stmtDefer(let stmt, _):
            checkStmt(stmt)
            // TODO(vdka): Validate that the deferal is unTerminated (defer cannot return)

        case .stmtFor(let initializer, let cond, let post, let body, _):
            var bodyScope = Scope(parent: context.scope)

            let prevContext = context
            defer { context = prevContext }
            context.scope = bodyScope

            info.scopes[node] = bodyScope
            if let initializer = initializer {
                checkStmt(initializer)
            }
            if let cond = cond {
                let type = checkExpr(cond)
                guard canImplicitlyConvert(type, to: Type.bool) else {
                    reportError("Non-bool \(cond.value) (type \(type)) used as condition", at: cond)
                    return
                }
            }
            if let post = post {
                checkStmt(post)
            }

            guard case .stmtBlock(let stmts, _) = body else {
                panic()
            }

            checkStmts(stmts)

        default:
            unimplemented("Checking for nodes of kind \(node.shortName)")
        }
    }

    mutating func checkStmts(_ nodes: [AstNode]) {

        for node in nodes {
            checkStmt(node)
        }
    }

    mutating func checkProcBody(_ pi: ProcInfo) {
        guard case .litProc(_, let body, _) = pi.node else {
            panic()
        }

        assert(info.types[pi.node] != nil)

        guard case .proc(let params, let results) = pi.type.kind else {
            panic()
        }

        guard case .stmtBlock(let stmts, _) = body else {

            let prevContext = context
            defer { context = prevContext }
            context.scope = pi.owningScope

            guard case .directive("foreign", let args, _) = body else {
                reportError("Expected a procedure body to be a block or foreign statement", at: body)
                return
            }

            guard let libNameNode = args[safe: 0], case .ident(let libName, let libLocation) = libNameNode else {
                reportError("Expected the name of the library the symbol will come from", at: args.last?.endLocation ?? body.endLocation)
                return
            }

            guard let entity = context.scope.lookup(libName) else {
                reportError("Undeclared name: '\(libName)'", at: libNameNode)
                return
            }

            guard case .libraryName = entity.kind else {
                reportError("Expected a library identifier", at: libNameNode)
                return
            }

            guard case .litString(let path, let pathLocation)? = args[safe: 1] else {
                reportError("Expected a string literal as the symbol to bind from the library", at: args.first?.startLocation ?? body.endLocation)
                return
            }

            return
        }

        openScope(body)
        defer { closeScope() }

        let prevContext = context
        let s = Scope(parent: pi.owningScope)
        s.isProc = true
        context.scope = s

        pi.decl?.entities.forEach({ $0.childScope = s })

        for entity in params {
            addEntity(to: s, entity)
        }

        pushProc(pi.type)
        defer { popProc() }

        checkStmts(stmts)

        // NOTE(vdka): There must be at least 1 return type or it's an error.
        guard let firstResult = results.first else {
            panic()
        }
        let voidResultTypes = results.count(where: { $0 === Type.void })
        if voidResultTypes > 1 {
            reportError("Multiple returns with a void value is forbidden.", at: pi.node)
        }

        let (terminatingStatements, branches) = terminatingStatments(body)
        guard branches.contains(.terminated) && !branches.contains(.unTerminated) || voidResultTypes == 1 else {
            reportError("Not all procedure body branches return", at: body) // FIXME(vdka): More context on this.
            return
        }

        for returnStmt in terminatingStatements {
            guard case .stmtReturn(let returnedExprs, _) = returnStmt else {
                panic() // implementation error in terminatingStatements
            }

            if returnedExprs.count == 0 && firstResult === Type.void {
                return
            }
            if returnedExprs.count < results.count {
                reportError("Too few return values for procedure. Expected \(results.count), got \(returnedExprs.count)", at: returnStmt)
                break
            } else if returnedExprs.count > results.count {
                reportError("Too many return values for procedure. Expected \(results.count), got \(returnedExprs.count)", at: returnStmt)
                break
            }

            for (returnExpr, resultType) in zip(returnedExprs, results) {
                let returnExprType = checkExpr(returnExpr)
                if !canImplicitlyConvert(returnExprType, to: resultType) {
                    reportError("Incompatible type for return expression. Expected '\(resultType)' but got '\(returnExprType)'", at: returnExpr)
                    continue
                }
            }
        }

        context = prevContext
    }

    @discardableResult
    mutating func checkExpr(_ node: AstNode) -> Type {
        if let type = info.types[node] {
            return type
        }

        if node.isDecl {
            fatalError("Use checkStmt instead")
        }

        var type = Type.invalid
        switch node {
        case .litInteger:
            type = Type.unconstrInteger

        case .litFloat:
            type = Type.unconstrFloat

        case .litString:
            type = Type.unconstrString

        case .ident:
            type = checkIdent(node)

        case .directive("file", let args, _):
            assert(args.isEmpty)
            type = Type.unconstrString

        case .directive("line", let args, _):
            assert(args.isEmpty)
            type = Type.unconstrInteger

        case .litProc:
            type = checkProcLitType(node)
            queueCheckProc(node, type: type, decl: nil) // no decl as this is an anon proc

        case .exprParen(let node, _):
            type = checkExpr(node)

        case .exprUnary:
            type = checkUnary(node)

        case .exprBinary:
            type = checkBinary(node)

        case .exprCall(let receiver, let args, _):
            let procType = checkExpr(receiver)
            guard case .proc(let params, let resultTypes) = procType.kind else {
                reportError("cannot call non-procedure '\(receiver.value)' (type \(procType))", at: node)
                break
            }

            if args.count < params.count {
                reportError("too few arguments to procedure '\(receiver.value)'", at: node)
                break
            } else if args.count > params.count {
                reportError("Too many arguments for procedure '\(receiver.value)", at: node)
                break
            }

            for (arg, param) in zip(args, params) {
                let argType = checkExpr(arg)
                if !canImplicitlyConvert(argType, to: param.type!) {
                    reportError("Incompatible type for argument, expected '\(param.type!)' but got '\(argType)'", at: arg)
                    continue
                }
            }

            guard resultTypes.count == 1, let firstResultType = resultTypes.first else {
                unimplemented("Type checking for calling procedures with multiple returns")
            }

            type = firstResultType

        case .exprSelector(let receiver, let member, _):

            //
            // TODO(vdka): This is temp code just to make importName entity have their members accessible. 
            //   Should be fine since we don't currently have structures of any sort.
            //

            guard let fileEntity = context.scope.lookup(receiver.identifier) else {
                panic() // NOTE: The 'tempness' of this code. Only works for importName entities
            }

            guard case .importName = fileEntity.kind else {
                panic()
            }

            guard case .ident(let memberName, _) = member else {
                panic()
            }

            guard let scopeEntity = fileEntity.childScope!.lookup(memberName) else {
                reportError("Member '\(memberName)' not found in file scope", at: member)
                return Type.invalid
            }

            checkEntity(scopeEntity)
            return scopeEntity.type!

        default:
            panic(node)
        }

        info.types[node] = type
        return type
    }

    struct Branch: OptionSet {
        let rawValue: UInt8

        /// Not a branch
        static let notApplicable = Branch(rawValue: 0b00)
        static let terminated    = Branch(rawValue: 0b01)
        static let unTerminated  = Branch(rawValue: 0b10)
    }

    /// - Returns: returns all nodes of kind `stmtReturn` that can be exit points for a scope.
    /// - Note: If not all branches terminate then an empty array is returned.
    func terminatingStatments(_ node: AstNode) -> ([AstNode], Branch) {

        switch node {
        case .stmtReturn:
            return ([node], .terminated)

        case .stmtExpr(let expr):
            return terminatingStatments(expr)

        case .stmtIf(_, let body, let elseExpr, _):
            let bodyTerminators = terminatingStatments(body)
            guard let elseExpr = elseExpr else {
                return (bodyTerminators.0, .unTerminated)
            }

            let elseTerminators = terminatingStatments(elseExpr)

            let allBranchesTerminate = bodyTerminators.1.union(elseTerminators.1)
            return (bodyTerminators.0 + elseTerminators.0, allBranchesTerminate)

        case .stmtBlock(let nodes, _):
            let stmts = nodes.map(terminatingStatments)

            return stmts.reduce(([AstNode](), Branch.notApplicable)) { prior, curr in
                return (prior.0 + curr.0, prior.1.union(curr.1))
            }

        // TODO(vdka): `switch` & `for`
        default:
            return ([], .notApplicable)
        }
    }

    mutating func checkUnary(_ node: AstNode) -> Type {
        guard case .exprUnary(let op, let expr, let location) = node else {
            panic()
        }

        switch op {
        case "+", "-": // valid on any numeric type.
            let operandType = checkExpr(expr)
            guard !Type.Flag.numeric.union(operandType.flags).isEmpty else {
                reportError("Undefined unary operation '\(op)' for \(operandType)", at: location)
                return Type.invalid
            }

            return operandType

        case "!", "~": // valid on any integer type.
            let operandType = checkExpr(expr)
            guard !Type.Flag.integer.union(operandType.flags).isEmpty else {
                reportError("Undefined unary operation '\(op)' for \(operandType)", at: location)
                return Type.invalid
            }

            return operandType

        default:
            reportError("Undefined unary operation '\(op)'", at: location)
            return Type.invalid
        }
    }

    mutating func checkBinary(_ node: AstNode) -> Type {
        guard case .exprBinary(let op, let lhs, let rhs, _) = node else {
            panic()
        }

        let lhsType = checkExpr(lhs)
        let rhsType = checkExpr(rhs)

        let invalidOpError = "Invalid operation binary operation \(op) between types \(lhsType) and \(rhsType)"

        switch op {
        case "+" where !Type.Flag.numeric.union(lhsType.flags).isEmpty && !Type.Flag.numeric.union(lhsType.flags).isEmpty,
             "-",
             "*",
             "/",
             "%":
            // NOTE(vdka): The first matching case duplicates this so that `string + string` doesn't enter this case body
            guard !Type.Flag.numeric.union(lhsType.flags).isEmpty && !Type.Flag.numeric.union(rhsType.flags).isEmpty else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }
            if lhsType === rhsType {
                return lhsType
            } else if canImplicitlyConvert(lhsType, to: rhsType) {
                attemptLiteralConstraint(lhs, to: rhsType)
                return lhsType
            } else if canImplicitlyConvert(rhsType, to: lhsType) {
                attemptLiteralConstraint(rhs, to: lhsType)
                return rhsType
            } else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

            // TODO(vdka): '%' modulo does % work on Float types?

        case "<<",
             ">>":
            guard !Type.Flag.integer.union(lhsType.flags).isEmpty && !Type.Flag.integer.union(rhsType.flags).isEmpty else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }
            if lhsType === rhsType {
                return lhsType
            } else if lhsType.flags.contains(.unconstrained) {
                attemptLiteralConstraint(lhs, to: rhsType)
                return rhsType
            } else if rhsType.flags.contains(.unconstrained) {
                attemptLiteralConstraint(rhs, to: lhsType)
                return lhsType
            } else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

        case "<",
             ">",
             "<=",
             ">=",
             "==":
            guard !Type.Flag.ordered.union(lhsType.flags).isEmpty && !Type.Flag.ordered.union(rhsType.flags).isEmpty else {
                    reportError(invalidOpError, at: node)
                    return Type.invalid
            }

            if lhsType === rhsType {
                // do nothing
            } else if lhsType.flags.contains(.unconstrained) {
                attemptLiteralConstraint(lhs, to: rhsType)
            } else if rhsType.flags.contains(.unconstrained) {
                attemptLiteralConstraint(rhs, to: lhsType)
            }

            return Type.bool

        case "&",
             "^",
             "|":
            guard lhsType.flags.contains(.integer) && rhsType.flags.contains(.integer) else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

            if lhsType === rhsType {
                return lhsType
            }
            if lhsType.size == rhsType.size {
                // FIXME(vdka): once we add more types with different sizes this check is not correct.
                assert(lhsType.flags.contains(.unsigned) != rhsType.flags.contains(.unsigned))
                reportError("Unable to infer type for result", at: node) // TODO(vdka): Better error
                return Type.invalid
            }
            if rhsType.flags.contains(.unconstrained) {
                attemptLiteralConstraint(rhs, to: lhsType)
            }
            if lhsType.flags.contains(.unconstrained) {
                attemptLiteralConstraint(rhs, to: rhsType)
            }
            if lhsType.size < rhsType.size {
                return rhsType
            }
            if lhsType.size > rhsType.size {
                return lhsType
            }

            panic()

        case "&&",
             "||":

            return Type.bool

        default:
            reportError(invalidOpError, at: node)
            return Type.invalid
        }
    }

    mutating func checkIdent(_ node: AstNode) -> Type {
        guard case .ident(let name, _) = node else {
            panic()
        }

        guard let e = context.scope.lookup(name) else {
            if name == "_" {
                reportError("'_' cannot be used as a value", at: node)
            } else {
                reportError("Undeclared name: '\(name)'", at: node)
            }

            return Type.invalid
        }

        addEntityUse(node, e)

        switch e.kind {
        case .importName:
            reportError("Invalid use of import '\(e.name)'", at: e.location)
            return Type.invalid

        case .libraryName:
            reportError("Invalid use of library '\(e.name)'", at: e.location)
            return Type.invalid

        case .invalid:
            // NOTE(vdka): Should have already warned about this.
            // NOTE(vdka): e.type is likely unset
            return Type.invalid

        default:
            // We should have a type by this point
            return e.type!
        }
    }
}


// MARK: Checker helpers

extension Checker {

    /// Updates the node's type to the target type if `node` matches the lit node for `type`
    mutating func attemptLiteralConstraint(_ node: AstNode, to type: Type) {

        switch node {
        case .litInteger:
            guard type.flags.contains(.integer) else { // We can't constrain a non integer type to an integer
                return
            }
            // NOTE(vdka): If we want to detect wrap in our literals we can do it here.

            info.types[node] = type

        case .litFloat:
            guard type.flags.contains(.float) else {
                return
            }

            info.types[node] = type

        case .litString:
            guard type.flags.contains(.string) else {
                return
            }

            info.types[node] = type
            
        default:
            return
        }
    }

    mutating func queueCheckProc(_ litProcNode: AstNode, type: Type, decl: DeclInfo?) {
        let procInfo = ProcInfo(owningScope: context.scope, decl: decl, type: type, node: litProcNode)
        procs.append(procInfo)
    }

    mutating func pushProc(_ type: Type) {
        procStack.append(type)
    }

    mutating func popProc() {
        procStack.removeLast()
    }

    mutating func openScope(_ node: AstNode) {
        assert(node.isType || node.isStmt)
        let scope = Scope(parent: context.scope)
        info.scopes[node] = scope
        if case .typeProc = node {
            scope.isProc = true
        }
        context.scope = scope
    }

    mutating func closeScope() {
        context.scope = context.scope.parent!
    }
}


// MARK: Universal helpers

extension Checker {

    static func pathToEntityName(_ path: String) -> (String, error: Bool) {
        precondition(!path.isEmpty)

        let filename = String(path.unicodeScalars
            .split(separator: "/").last!
            .split(separator: ".").first!)

        if isValidIdentifier(filename) {
            return (filename, error: false)
        } else {
            return ("_", error: true)
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
