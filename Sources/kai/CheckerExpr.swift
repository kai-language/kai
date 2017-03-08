
extension Checker {

    mutating func checkType(_ e: Entity, typeExpr: AstNode, def: Type? = nil) -> Type {
        unimplemented("Checking any expr type")
    }

    mutating func checkExprOrType(_ operand: Operand, expr: AstNode) {
        unimplemented(#function)
    }
}
