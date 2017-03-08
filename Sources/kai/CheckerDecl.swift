
extension Checker {

    mutating func checkEntityDecl(_ e: Entity, _ d: DeclInfo, namedType: Type?) {
        guard e.type == nil else {
            return // Done previously
        }

        var prevContext = context
        defer { context = prevContext }
        context.scope = d.scope
        context.decl = d

        switch e.kind {
        case .runtime:
            unimplemented("Type checking for variable type entities")

        case .compileTime:
            unimplemented("Type checking for contant type entities")

        case .typeName:
            unimplemented("Type checking for named type entities")

        case .procedure:
            unimplemented("Type checking for procedure type entities")

        case .builtin,
             .importName,
             .invalid,
             .libraryName,
             .nil:

            break
        }
    }

    mutating func checkInitConstant(_ e: Entity, op: Operand) {

        if op.kind == .invalid {
            if e.type == nil {
                e.type = .invalid
            }
        }

        if op.kind != .compileTime {

            // TODO(vdka): Op needs to store an expr node.
            reportError("`\(op.expr!)` is not a constant", at: op.expr!)
            if e.type == nil {
                e.type = .invalid
            }
            return
        }

        // TODO(vdka): Ensure op.type.isConstantType

        if e.type == nil { // NOTE(vdka): Type inference
            e.type = op.type
        }

        e.kind = .compileTime(op.value)
    }

    mutating func checkCompileTimeDecl(_ e: Entity, typeExpr: AstNode?, valueExpr: AstNode?, namedType: Type?) {

        guard case .compileTime = e.kind else { preconditionFailure() }
        assert(e.type == nil)

        if e.flags.contains(.visited) {
            // TODO(vdka): @Understand
            e.type = .invalid
            return
        }
        e.flags.insert(.visited)

        if let typeExpr = typeExpr {
            let type = checkType(e, typeExpr: typeExpr)
            if !type.isConstantType {
                reportError("Invalid constant type \(type)", at: typeExpr)
                e.type = .invalid
                return
            }

            e.type = type
        }

        let operand = Operand()
        if let valueExpr = valueExpr {
            checkExprOrType(operand, expr: valueExpr)
        }

        if case .type = operand.kind {
            e.kind = .typeName

            var d = context.decl!
            d.typeExpr = valueExpr
            // TODO(vdka): Are we certain that typeExpr is non nil here?
            checkTypeDecl(e, typeExpr: d.typeExpr!, def: namedType)
            return
        }

        checkInitConstant(e, op: operand)

        if operand.kind == .invalid {

            reportError("Invalid declaration type", at: e.location)
        }
    }

    mutating func checkTypeDecl(_ e: Entity, typeExpr: AstNode, def: Type?) {
        assert(e.type == nil)
        let named = Type(kind: .named(e.name, base: nil, typeName: e))
        if let def = def, case .named = def.kind {
            unimplemented()
        }
        e.type = named

        // TODO(vdka): Check base type.
    }
}
