
struct Operand {
    var type: Type!
    var constant: Value?
    var dependencies: Set<Entity> = []
    // var overloads: [Entity]? = [] // soon™

    static let invalid = Operand(type: ty.invalid, constant: nil, dependencies: [])

//    @available(*, unavailable)
    static let todo = Operand()

    enum Mode {
        case invalid
        /// computed value or literal
        case value
        /// addressable variable
        case variable
    }
}

/*
struct Operand {
    AddressingMode mode;
    Type *         type;
    ExactValue     value;
    AstNode *      expr;
    BuiltinProcId  builtin_id;
    isize          overload_count;
    Entity **      overload_entities;
};
*/
