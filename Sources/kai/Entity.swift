
/*
 typedef struct Scope {
	Scope *        parent;
	Scope *        prev, *next;
	Scope *        first_child;
	Scope *        last_child;
	MapEntity      elements; // Key: String
	MapBool        implicit; // Key: Entity *

	Array(Scope *) shared;
	Array(Scope *) imported;
	bool           is_proc;
	bool           is_global;
	bool           is_file;
	bool           is_init;
	bool           has_been_imported; // This is only applicable to file scopes
	AstFile *      file;
 } Scope;
 */

struct Entity {
    var kind: Kind
    var flags: Flag
    var token: Lexer.Token?
    var symbol: Symbol?
    var symbolTable: SymbolTable?
    var type: Type?
    var identifier: AST.Node?


}

extension Entity {

    enum Kind {
        case invalid
        case constant
        case variable
        case typeName
        case procedure
        case builtin
        case importName
        case libraryName
        case `nil`
    }

    struct Flag: OptionSet {
        var rawValue: UInt16
        init(rawValue: UInt16) { self.rawValue = rawValue }

        static let visited   = 0b00000001
        static let used      = 0b00000010
        static let anonymous = 0b00000100
        static let field     = 0b00001000
        static let param     = 0b00010000
        static let ellipsis  = 0b00100000
        static let noAlias   = 0b01000000
        static let typeField = 0b10000000
    }
}

/*
struct Entity {
    EntityKind kind;
    u32        flags;
    Token      token;
    Scope *    scope;
    Type *     type;
    AstNode *  identifier; // Can be NULL

    // TODO(bill): Cleanup how `using` works for entities
    Entity *   using_parent;
    AstNode *  using_expr;

    union {
    struct {
        ExactValue value;
    } Constant;
    struct {
        i32  field_index;
        i32  field_src_index;
        bool is_immutable;
        bool is_thread_local;
    } Variable;
    i32 TypeName;
    struct {
        bool         is_foreign;
        String       foreign_name;
        Entity *     foreign_library;
        String       link_name;
        u64          tags;
        OverloadKind overload_kind;
    } Procedure;
    struct {
        i32 id;
    } Builtin;
    struct {
        String path;
        String name;
        Scope *scope;
        bool   used;
    } ImportName;
    struct {
        String path;
        String name;
        bool   used;
    } LibraryName;
    i32 Nil;
    };
};
*/
