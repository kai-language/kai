
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

    var file: ASTFile

    static var universal: Scope = {

        let s = Scope(parent: nil)

        // TODO(vdka): Insert types into universal scope

        for type in BasicType.allBasicTypes {

        }
        
        /*
            BuildContext *bc = &build_context;
            // NOTE(bill): No need to free these
            gbAllocator a = heap_allocator();
            universal_scope = make_scope(NULL, a);

            // Types
            for (isize i = 0; i < gb_count_of(basic_types); i++) {
                add_global_entity(make_entity_type_name(a, NULL, make_token_ident(basic_types[i].Basic.name), &basic_types[i]));
            }
            for (isize i = 0; i < gb_count_of(basic_type_aliases); i++) {
                add_global_entity(make_entity_type_name(a, NULL, make_token_ident(basic_type_aliases[i].Basic.name), &basic_type_aliases[i]));
            }

            // Constants
            add_global_constant(a, str_lit("true"),  t_untyped_bool,    make_exact_value_bool(true));
            add_global_constant(a, str_lit("false"), t_untyped_bool,    make_exact_value_bool(false));

            add_global_entity(make_entity_nil(a, str_lit("nil"), t_untyped_nil));
            add_global_entity(make_entity_library_name(a,  universal_scope,
                                                       make_token_ident(str_lit("__llvm_core")), t_invalid,
                                                       str_lit(""), str_lit("__llvm_core")));

            // TODO(bill): Set through flags in the compiler
            add_global_string_constant(a, str_lit("ODIN_OS"),      bc->ODIN_OS);
            add_global_string_constant(a, str_lit("ODIN_ARCH"),    bc->ODIN_ARCH);
            add_global_string_constant(a, str_lit("ODIN_ENDIAN"),  bc->ODIN_ENDIAN);
            add_global_string_constant(a, str_lit("ODIN_VENDOR"),  bc->ODIN_VENDOR);
            add_global_string_constant(a, str_lit("ODIN_VERSION"), bc->ODIN_VERSION);
            add_global_string_constant(a, str_lit("ODIN_ROOT"),    bc->ODIN_ROOT);


            // Builtin Procedures
            for (isize i = 0; i < gb_count_of(builtin_procs); i++) {
                BuiltinProcId id = cast(BuiltinProcId)i;
                Entity *entity = alloc_entity(a, Entity_Builtin, NULL, make_token_ident(builtin_procs[i].name), t_invalid);
                entity->Builtin.id = id;
                add_global_entity(entity);
            }
            
            
            t_u8_ptr       = make_type_pointer(a, t_u8);
            t_int_ptr      = make_type_pointer(a, t_int);
            t_i64_ptr      = make_type_pointer(a, t_i64);
            t_f64_ptr      = make_type_pointer(a, t_f64);
            t_byte_slice   = make_type_slice(a, t_byte);
            t_string_slice = make_type_slice(a, t_string);
         */
    }()

    init(parent: Scope?) {
        self.parent = parent
    }
}

struct DeclInfo {
	var scope: Scope

	var entities: [Entity]

	var typeExpr: AST.Node
	var initExpr: AST.Node
	var procLit:  AST.Node // AstNode_ProcLit

    /// The entities this entity requires to exist
    var deps: Set<Entity>
}

struct Checker {
    var file: ASTFile
    var info: Info
    var globalScope: Scope
    var context: Context
    var procStack: [Type]
    /*
	Array(ProcedureInfo)   procs; // NOTE(bill): Procedures to check
	Array(DelayedDecl)     delayed_imports;
	Array(DelayedDecl)     delayed_foreign_libraries;

	gbArena                arena;
	gbArena                tmp_arena;
	gbAllocator            allocator;
	gbAllocator            tmp_allocator;

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

func addDefinition(_ decl: AST.Node) {

}

func reportError(_ message: String, at node: AST.Node) {
    print("ERROR(\(node.location?.description ?? "unkown")): " + message)
}

func reportError(_ message: String, at location: SourceLocation) {
    print("ERROR(\(location.description)): " + message)
}
