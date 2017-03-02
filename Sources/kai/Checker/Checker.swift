

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
            let e = Entity(kind: .typeName, flags: [], scope: s, location: nil, identifier: nil)
            s.insert(e, named: type.name)
        }

        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(true), scope: s)

        let e = Entity(kind: .nil, scope: s, location: nil, identifier: nil)
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

    var typeExpr: AstNode
    var initExpr: AstNode
    var procLit:  AstNode // AstNode_ProcLit
    
    /// The entities this entity requires to exist
    var deps: Set<Entity>
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
    var file: ASTFile
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
