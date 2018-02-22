
struct Operand {
    // TODO:
    var mode: Mode
    var expr: Expr?
    var type: Type!
    var constant: Value?
    var dependencies: Set<Entity> = []
    // var overloads: [Entity]? = [] // soon™

    static let invalid = Operand(mode: .invalid, expr: BadExpr(start: noPos, end: noPos), type: ty.invalid, constant: nil, dependencies: [])

    enum Mode {
        case invalid
        /// computed value or literal
        case computed
        /// assignable is a special mode that is not addressable, but *is* assignable. It may require some computation (extracting a V2 out of a V3 swizzle)
        case assignable
        /// addressable variable or member of aggregate
        case addressable
        case `nil`
        /// void returns
        case novalue
        /// file
        case file
        /// library
        case library
        /// a type
        case type
    }
}

extension Operand: CustomStringConvertible {
    var description: String {

        let expr = self.expr.map({ "'" + String(describing: $0) + "' " }) ?? ""

        // TODO: improve these
        switch mode {
        case .invalid, .computed, .addressable, .assignable:
            return expr + "(type \(type!))"
        case .novalue:
            return type.description
        case .nil:
            return "nil"
        case .type:
            return type.description
        case .file:
            return "file" + (self.expr.map({ " '" + String(describing: $0) + "'" }) ?? "")
        case .library:
            return "library"
        }
    }
}
