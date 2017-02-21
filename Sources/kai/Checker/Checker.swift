
void add_entity_definition(CheckerInfo *i, AstNode *identifier, Entity *entity) {
    GB_ASSERT(identifier != NULL);
    if (identifier->kind == AstNode_Ident) {
        if (str_eq(identifier->Ident.string, str_lit("_"))) {
            return;
        }
        HashKey key = hash_pointer(identifier);
        map_entity_set(&i->definitions, key, entity);
    } else {
        // NOTE(bill): Error should handled elsewhere
    }
}


func addDefinition(_ decl: AST.Node) {
    
}

func reportError(_ message: String, at node: AST.Node) {
    print("ERROR(\(node.location?.description ?? "unkown")): " + message)
}
