
/// Defines a type declaration
class TypeRecord {

    var name: String?
    var kind: Kind
    var flags: Flag
    var size: UInt
    var location: SourceLocation?

    // TODO(vdka): Give procedures an actual record.
    static let procedure = TypeRecord(name: nil, kind: .builtin, flags: .none, size: 0, location: nil)

    init(name: String?, kind: Kind, flags: Flag, size: UInt, location: SourceLocation?) {
        self.name = name
        self.kind = kind
        self.flags = flags
        self.size = size
        self.location = location
    }

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

/// Defines a type in which something can take
class Type {

    var kind: Kind
    var record: TypeRecord

    init(kind: Kind, record: TypeRecord) {
        self.kind = kind
        self.record = record
    }

    enum Kind {
        case named
        case builtin
        case metatype
        case proc(params: [Entity], returns: [Type])
    }
}

enum std {

    static let types: String = "stdtypes.kai"
}

extension Type {

    var metatype: Type {
        return Type(kind: .metatype, record: record)
    }

    static let builtin: [Type] = {

        // NOTE(vdka): Order is important later.
                  /* Name,   size, line, flags */
        let short: [(String, UInt, UInt, TypeRecord.Flag)] = [
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

            let record = TypeRecord(name: name, kind: .builtin, flags: flags, size: size, location: location)

            return Type(kind: .named, record: record)
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

    static let string = builtin[12]

    static let unconstrBool     = builtin[13]
    static let unconstrInteger  = builtin[14]
    static let unconstrFloat    = builtin[15]
    static let unconstrString   = builtin[16]
    static let unconstrNil      = builtin[17]

    static let invalid = builtin[18]
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
        case type

        case importName  //path, name: String, scope: Scope, used: Bool)
        case libraryName // (path, name: String, used: Bool)
        case invalid
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
    var children: [Scope] = []
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

            guard let location = type.record.location else {
                panic()
            }

            let e = Entity(name: type.record.name!, location: location, kind: .type, owningScope: s)
            e.type = type.metatype
            s.insert(e)
        }

        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(true), scope: s)

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

struct ProcInfo {
    var decl: DeclInfo
    var type: Type
    var node: AstNode // AstNode.litProc
}

class DeclInfo: PointerHashable {

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
        var entities:    [Entity: DeclInfo] = [:]
        var types:       [AstNode: Type]    = [:] // Key: AstNode.expr*
        var definitions: [AstNode: Entity]  = [:] // Key: AstNode.ident
        var uses:        [AstNode: Entity]  = [:] // Key: AstNode.ident
        var scopes:      [AstNode: Scope]   = [:] // Key: Any AstNode
    }

    struct Context {
        var scope: Scope
        var fileScope: Scope? = nil
        var inDefer: Bool     = false

        init(scope: Scope) {
            self.scope = scope

            fileScope = nil
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
        }

        importEntities(&fileScopes)

        let firstScope = fileScopes[parser.files[0].fullpath]!
        checkEntities(in: firstScope)

        for pi in procs {
            let prevContext = context

            checkProcBody(pi.decl, pi.type, pi.node)

            context = prevContext
        }
    }

    mutating func collectEntities(_ nodes: [AstNode]) {

        for node in nodes {

            if context.scope.isFile, !node.isDecl {
                reportError("Currently only declarations are valid at file scope", at: node)
                continue
            }

            switch node {
            case .declValue(let isRuntime, let names, let type, let values, _):

                for (index, name) in names.enumerated() {

                    guard name.isIdent else {
                        reportError("A declaration's name must be an identifier", at: name)
                        continue
                    }

                    let value = values[safe: index].map(unparenExpr)

                    let declInfo = DeclInfo(scope: context.scope)
                    var entity: Entity
                    if let value = value, value.isType {
                        entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                        declInfo.typeExpr = value
                        declInfo.initExpr = value
                    } else if let value = value, case .litProc = value {

                        // TODO(vdka): Some validation around explicit typing for procLits?
                        /*
                         someProc : (int) -> void : (n: int) -> void { /* ... */ }
                         */

                        entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                        declInfo.initExpr = value
                    } else {
                        entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                        declInfo.typeExpr = type
                        declInfo.initExpr = value
                    }

                    declInfo.entities.append(entity)

                    addEntity(to: declInfo.scope, entity)

                    // TODO(vdka): Check entities are not used in their own intialization.
                    info.entities[entity] = declInfo
                    info.definitions[name] = entity
                }
                checkArityMatch(node)

            case .declImport, .declLibrary:
                if !context.scope.isFile {
                    reportError("#import and #library directives are only valid at file scope", at: node)
                }

                let decl = DelayedDecl(parent: context.scope, decl: node)
                delayedImports.append(decl)

            default:
                // The node doesn't declare anything
                assert(!context.scope.isFile)
                break
            }
        }
    }

    mutating func importEntities(_ fileScopes: inout [String: Scope]) {

        for imp in delayedImports {
            guard case .declImport(let path, let fullpathOpt, let importName, _) = imp.decl else {
                panic()
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

        for _ in delayedLibaries {
            unimplemented("Foreign libraries") // TODO(vdka): This should be super easy.
        }
    }

    mutating func checkEntities(in scope: Scope) {

        for entity in scope.elements.values {
            guard let decl = info.entities[entity] else {
                panic()
            }

            // TODO(vdka): Should this be global
            if scope.isMainFile, entity.name == "main" {
                main = entity
            }

            fillType(decl)
        }
    }

    mutating func setCurrentFile(_ file: ASTFile) {
        self.currentFile = file
        self.context.scope = file.scope!
        self.context.fileScope = file.scope!
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

                var paramEntities: [Entity] = []
                var returnTypes:   [Type]   = []

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

                            let e = Entity(identifier: ident, kind: .runtime, owningScope: scope)
                            let paramDecl = DeclInfo(scope: scope, entities: [e], typeExpr: type, initExpr: nil)

                            fillType(paramDecl)

                            paramEntities.append(e)

                            info.definitions[ident] = e
                            info.entities[e] = paramDecl

                        default:
                            // TODO(vdka): Validate that the procedure has a foreign body if arg names are omitted.

                            let type = lookupType(param)

                            // Generate a dummy entity for foreign body procedures
                            let e = Entity(name: "_", location: param.startLocation, kind: .runtime, owningScope: scope)

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

                    type = Type(kind: .proc(params: paramEntities, returns: returnTypes), record: .procedure)

                    let procInfo = ProcInfo(decl: d, type: type, node: initExpr)
                    procs.append(procInfo)

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
            case .type:
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

    mutating func checkProcBody(_ decl: DeclInfo, _ type: Type, _ lit: AstNode) {
        guard case .litProc(_, let body, _) = lit else {
            panic()
        }

        guard case .proc(let params, let results) = type.kind else {
            panic()
        }

        guard case .stmtBlock(let stmts, _) = body else {
            fatalError() // TODO(vdka): Report error
        }

        let prevContext = context
        let s = Scope(parent: decl.scope)
        context.scope = s

        pushProc(type)

        collectEntities(stmts)
        checkEntities(in: s)
        switch (results.count, results.first) {
        case (1, let type?) where type !== Type.void: // no return stmt needed
            break

        default: // Requires return stmt
            // FIXME(vdka): Be smarter. There are way more cases.
            if !(stmts.last?.isTerminating ?? false) {
                reportError("Missing return at end of procedure", at: body.endLocation)
            }
        }

        popProc()

        context = prevContext
    }
}


// MARK: Checker helpers

extension Checker {

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
