
extension Checker {

    mutating func checkIdent(_ o: Operand, _ n: AstNode, namedType: Type?, typeHint: Type?) {
        assert(n.isIdent)
        o.kind = .invalid
        o.expr = n
        let name = n.identifier

        guard let e = context.scope.lookup(name) else {
            if name == "_" {
                reportError("`_` cannot be used as a type", at: n)
            } else {
                reportError("Undeclared name: \(name)", at: n)
            }
            o.type = .invalid
            o.kind = .invalid
            if namedType != nil {
                // TODO(vdka): Invalidate the underlaying namedType
            }
            return
        }

        if case .procedure = e.kind {
            // TODO(vdka): Allow overloads.
        }
    }

    mutating func checkType(_ e: AstNode, namedType: Type?) -> Type {

        switch e {
        case .ident:
            unimplemented("Ident lookup during type checking")

        case .expr(.selector):
            unimplemented("Selector lookup for type checking")

        case .expr(.paren(expr: let expr, _)):
            return checkType(expr, namedType: namedType)

        case .expr(.unary(op: let op, expr: let expr, _)):
            unimplemented("Unary operator type checking")

        default:
            unimplemented()
        }
    }

    mutating func checkType(_ e: Entity, typeExpr: AstNode, def: Type? = nil) -> Type {
        unimplemented("Checking any expr type")
    }

    mutating func checkExprOrType(_ operand: Operand, expr: AstNode) {

        switch expr {
        case .literal(let lit):
            switch lit {
            case .basic(let basic, _):
                operand.kind = .compileTime
                switch basic {
                case .float(let val):
                    operand.type = Type.unconstrFloat
                    operand.value = .float(val)

                case .integer(let val):
                    operand.type = Type.unconstrInteger
                    operand.value = .integer(val)

                case .string(let val):
                    operand.type = Type.unconstrString
                    operand.value = .string(val)
                }

            case .compound(_),
                 .proc(_):
                unimplemented("Type checking for compund or proc literals")
            }

        default:
            unimplemented("\(#function) for \(expr.shortName)")
        }
    }
}
