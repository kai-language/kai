

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
            let e = Entity(kind: .typeName, flags: [], scope: s, identifier: nil)
            s.insert(e, named: type.name)
        }

        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(true), scope: s)

        let e = Entity(kind: .nil, scope: s, identifier: nil)
        e.type = Type.unconstrNil
        s.insert(e, named: "nil")

        return s
    }()

    init(parent: Scope?) {
        self.parent = parent
    }
}

extension Scope {

    // NOTE(vdka): Should this return an error?
    func insert(_ entity: Entity, named name: String) {

        guard !elements.keys.contains(name) else {
            reportError("Conflicting definition", at: entity.location ?? .unknown)
            return
        }

        elements[name] = entity
    }

    func lookup(_ name: String) -> Entity? {

        if let entity = elements[name] {
            return entity
        } else {
            return parent?.lookup(name)
        }
    }
}

struct DeclInfo {

    unowned var scope: Scope

    var entities: [Entity]

    var typeExpr: AstNode?
    var initExpr: AstNode?
    // TODO(vdka): This should be an enum _kind_
//    var procLit:  AstNode // AstNode_ProcLit

    /// The entities this entity requires to exist
//    var deps: Set<Entity>

    init(scope: Scope, entities: [Entity] = [], typeExpr: AstNode? = nil, initExpr: AstNode? = nil) {
        self.scope = scope
        self.entities = entities
        self.typeExpr = typeExpr
        self.initExpr = initExpr
    }
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

    var procs: [ProcInfo]

    var procStack: [Type]
    /*
	Array(ProcedureInfo)   procs; // NOTE(bill): Procedures to check
	Array(DelayedDecl)     delayed_imports;
	Array(DelayedDecl)     delayed_foreign_libraries;

	Array(Type *)          proc_stack;
	bool                   done_preload;
    */

    struct Info {
        var types:       [AstNode: Type]    = [:]
        var definitions: [AstNode: Entity]  = [:]
        var uses:        [AstNode: Type]    = [:]
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
        var fileScope: Scope
        var scope: Scope
        var decl: DeclInfo?
        var inDefer: Bool
        var procName: String?
        var typeHint: Type?
    }
}


// MARK: Checker functions

extension Checker {

    mutating func checkParsedFiles() {

        var fileScopes: [String: Scope] = [:]

        for file in parser.files {
            let scope = Scope(parent: nil) // TODO(vdka): universal scope is parent?
            scope.isGlobal = true // TODO(vdka): Are files from the parser automatically in _global_
            scope.isFile = true
            scope.file = file
            scope.isInit = true // TODO(vdka): Is this the first scope we parsed? (The file the compiler was called upon)

            if scope.isGlobal {
                globalScope.shared.append(scope)
            }

            file.scope = scope // Dep
            fileScopes[file.fullpath] = scope
        }

        for file in parser.files {
            let prevContext = context

            setCurrentFile(file)

            collectEntities(file.nodes, isFileScope: true)

            context = prevContext
        }
        // Collect all of a files decls (from top level? further because of nested types)
    }

    mutating func collectEntities(_ nodes: [AstNode], isFileScope: Bool) {
        if isFileScope {
            assert(context.scope.isFile)
        } else {
            assert(!context.scope.isFile)
        }

        for node in nodes {

            guard case .decl(let decl) = node else {
                // NOTE(vdka): For now only declarations are valid at file scope.
                // TODO(vdka): Report an error
                continue
            }

            switch decl {
            case .bad:
                break

            case let .value(isVar, names, type, values, _):
                if isVar {
                    if context.scope.isFile {
                        // NOTE(vdka): handle later.
                        break
                    }

                    var entities: [Entity] = []
                    var declInfo: DeclInfo?
                    if !names.isEmpty {
                        declInfo = DeclInfo(scope: context.scope, entities: entities, typeExpr: type, initExpr: nil)
                    }

                    // we will always have more names than values because we won't be supporting tuple splatting
                    for (index, name) in names.enumerated() {
                        let value = values[safe: index]

                        guard name.isIdent else {
                            reportError("A declaration's name must be an identifier", at: name)
                            continue
                        }

                        // TODO(vdka): Flags
                        let entity = Entity(kind: .variable, scope: context.scope, identifier: name)
                        entities.append(entity)

                        if declInfo == nil {
                            declInfo = DeclInfo(scope: entity.scope, typeExpr: type, initExpr: value)
                        }

                        func addEntityAndDeclInfo(ident: AstNode, _ entity: Entity, _ declInfo: DeclInfo) {
                            assert(ident.isIdent)
                        }

                        info.entities[entity] = declInfo!

                        /*
                        DeclInfo *d = di;
                        if (d == NULL) {
                            AstNode *init_expr = value;
                            d = make_declaration_info(heap_allocator(), e->scope);
                            d->type_expr = vd->type;
                            d->init_expr = init_expr;
                        }
                        
                        add_entity_and_decl_info(c, name, e, d);
                         
                         void add_entity_and_decl_info(Checker *c, AstNode *identifier, Entity *e, DeclInfo *d) {
                             GB_ASSERT(identifier->kind == AstNode_Ident);
                             GB_ASSERT(e != NULL && d != NULL);
                             GB_ASSERT(str_eq(identifier->Ident.string, e->token.string));
                             add_entity(c, e->scope, identifier, e);
                             map_decl_info_set(&c->info.entities, hash_pointer(e), d);
                         }

                        */
                    }
                    checkArityMatch(node)

                } else {
                    
                }
                break

            case let .import(relativePath, fullPath, importName, location):
                break

            case let .library(filePath, libName, location):
                break
            }
        }
    }

    mutating func setCurrentFile(_ file: ASTFile) {
        self.currentFile = file
        self.context.decl = file.declInfo
        self.context.scope = file.scope!
        self.context.fileScope = file.scope!
    }

    @discardableResult
    mutating func checkArityMatch(_ node: AstNode) -> Bool {
        guard case .decl(.value(let decl)) = node else { preconditionFailure() }

        if decl.values.isEmpty && decl.type == nil {
            reportError("Missing type or initial expression", at: node)
            return false
        } else if decl.names.count < decl.values.count {
            reportError("Arity mismatch, excess expressions on rhs", at: decl.values[decl.names.count])
            return false
        } else if decl.names.count > decl.values.count && decl.values.count != 1 {
            // TODO(vdka): Should check that if we have just 1 rhs value it expands into the correct number of lhs values.
            /*
             someThing :: () -> int, error { /* ... */ }
             x, err := someThing() // good
             y, z   := x // bad (but would pass this check)
            */
            reportError("Arity mismath, missing expressions for ident", at: decl.names[decl.values.count])
            return false
        }

        return true
    }
}

enum ErrorType {
    case syntax
    case typeMismatch
    case `default`
}

func reportError(_ message: String, at node: AstNode, with type: ErrorType = .default) {
    print("ERROR(\(node.location.description)): " + message)
}

func reportError(_ message: String, at location: SourceLocation) {
    print("ERROR(\(location.description)): " + message)
}
