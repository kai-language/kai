
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
        var types:       [AST.Node: Type]    = [:]
        var definitions: [AST.Node: Entity]  = [:]
        var uses:        [AST.Node: Type]    = [:]
        var scopes:      [AST.Node: Scope]   = [:]
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

extension Checker {

}

func reportError(_ message: String, at node: AST.Node) {
    print("ERROR(\(node.location?.description ?? "unkown")): " + message)
}

func reportError(_ message: String, at location: SourceLocation) {
    print("ERROR(\(location.description)): " + message)
}
