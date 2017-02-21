
func checkType(_ expr: AST.Node) throws {
    var type: TypeRecord = .invalid

    switch expr.kind {
    case .identifier(_):
        checkIdentfier(expr)

    default:
        break
    }
}

func checkIdentfier(_ node: AST.Node) {
    guard case .identifier(let name) = node.kind else { preconditionFailure() }

    guard let symbol = SymbolTable.current.lookup(name) else {
        reportError("Undeclared name: \(name.string)", at: node)

//        node.
        return
    }
//
//
//    Entity *e = scope_lookup_entity(c->context.scope, name);
//    if (e == NULL) {
//        if (str_eq(name, str_lit("_"))) {
//            error(n->Ident, "`_` cannot be used as a value type");
//        } else {
//            error(n->Ident, "Undeclared name: %.*s", LIT(name));
//        }
//        o->type = t_invalid;
//        o->mode = Addressing_Invalid;
//        if (named_type != NULL) {
//            set_base_type(named_type, t_invalid);
//        }
//        return;
//    }

}
