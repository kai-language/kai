
//void add_entity_definition(CheckerInfo *i, AstNode *identifier, Entity *entity) {
//    GB_ASSERT(identifier != NULL);
//    if (identifier->kind == AstNode_Ident) {
//        if (str_eq(identifier->Ident.string, str_lit("_"))) {
//            return;
//        }
//        HashKey key = hash_pointer(identifier);
//        map_entity_set(&i->definitions, key, entity);
//    } else {
//        // NOTE(bill): Error should handled elsewhere
//    }
//}

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
