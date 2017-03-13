

class Scope {
    weak var parent: Scope?
    var prev: Scope?
    var next: Scope?
    var children: [Scope?] = []
    var elements: [String: Entity] = [:]
    var implicit: [Entity: Bool] = [:]

    var shared: [Scope] = []
    var imported: [Scope] = []
    var isProc:   Bool = false
    var isGlobal: Bool = false
    var isFile:   Bool = false
    var isInit:   Bool = false
    /// Only relevant for file scopes
    var hasBeenImported: Bool = false

    var file: ASTFile?

    static var universal: Scope = {

        var s = Scope(parent: nil)

        // TODO(vdka): Insert types into universal scope

        for type in BasicType.allBasicTypes {
            let e = Entity(kind: .typeName, name: type.name, location: .unknown, flags: [], scope: s, identifier: nil)
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

// TODO(vdka): Fill this in.
/// Used to store intermediate information during type checking.
class Operand {

    var kind: Kind
    var type: Type?
    var expr: AstNode?
    var value: ExactValue

    init(kind: Kind = .invalid, expr: AstNode? = nil) {
        self.kind = kind
        self.type = nil
        self.expr = expr
        self.value = .invalid
    }

    enum Kind {
        case invalid
        case noValue
        case value
        case runtime
        case compileTime
        case type
    }

    static let invalid = Operand(kind: .invalid)
}

class DeclInfo {

    unowned var scope: Scope

    var entities: [Entity]

    var typeExpr: AstNode?
    var initExpr: AstNode?
    // TODO(vdka): This should be an enum _kind_
//    var procLit:  AstNode // AstNode_ProcLit

    /// The entities this entity requires to exist
    var deps: Set<Entity> = []

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

struct TypeAndValue {
    var type: Type
    var value: ExactValue
}

/// stores information used for "untyped" expressions
struct UntypedExprInfo {
    var isLhs: Bool
    var type: Type
    var value: ExactValue
}

struct Checker {
    var parser: Parser
    var currentFile: ASTFile
    var info: Info
    var globalScope: Scope
    var context: Context

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
                    } else if let value = value, case .litProc(let procType, _, _) = value {

                        // TODO(vdka): Some validation around:
                        /*
                         someProc : (int) -> void : (n: int) -> void { /* ... */ }
                         */

                        entity = Entity(kind: .procedure, name: name.identifier, scope: declInfo.scope, identifier: name)
                        declInfo.initExpr = value
                        declInfo.typeExpr = procType
                    } else {
                        entity = Entity(kind: .compileTime(.invalid), name: name.identifier, scope: declInfo.scope, identifier: name)
                        declInfo.typeExpr = type
                        declInfo.initExpr = value
                    }

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

            if d.scope !== e.scope { // TODO(vdka): Understand why this may happen and it's implications better.
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

            checkEntityDecl(e, d, namedType: nil)
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

    mutating func addEntityUse(identifier: AstNode, _ e: Entity) {
        guard identifier.isIdent else {
            return
        }

        info.uses[identifier] = e
    }

    mutating func addDeclarationDependency(_ e: Entity) {
        /*
        guard let decl = context.decl else { return }

        if let found = info.entities[e] {
            addDependency(context.decl!, e)
        }
        */
    }

    mutating func addDependency(_ d: DeclInfo, _ e: Entity) {
        d.deps.insert(e)
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

enum ErrorType {
    case syntax
    case typeMismatch
    case `default`
}

func reportError(_ message: String, at node: AstNode, with type: ErrorType = .default) {
    print("ERROR(\(node.startLocation.description)): " + message)
}

func reportError(_ message: String, at location: SourceLocation) {
    print("ERROR(\(location.description)): " + message)
}

func reportError(_ message: String, at location: SourceRange) {
    print("ERROR(\(location.description)): " + message)
}
