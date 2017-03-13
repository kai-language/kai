
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
            checkCompileTimeDecl(e, typeExpr: d.typeExpr, valueExpr: d.initExpr, namedType: nil)

        case .typeName:
            unimplemented("Type checking for named type entities")

        case .procedure:
            checkProcLit(e, d)

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

            if let expr = op.expr {
                reportError("`\(expr)` is not a constant", at: expr)
            }
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

    mutating func checkProcLit(_ e: Entity, _ d: DeclInfo) {
        assert(e.type == nil)

        guard let procExpr = d.initExpr, procExpr.isProcLit else {
            reportError("Expected a procedure to check", at: e.location)
            return
        }

        if (d.scope.isFile || d.scope.isGlobal || d.scope.isInit) && e.name == "main" {
            // FIXME(vdka): Lookup and validate 'main' symbol
            /*
            guard case .literal(.proc(let source, type: let type, _)) = procExpr else {
                preconditionFailure()
            }
            guard case .type(.proc(params: let params, results: let results, _)) = type else {
                reportError("Symbol 'main' must be a procedure type", at: procExpr)
                return
            }
            */
        }
    }

    mutating func checkProcedureType(_ procType: AstNode) -> Type {

        fatalError()
    }

    mutating func checkGetParamTypes(_ scope: Scope, params: AstNode) -> ([Type], isVariadic: Bool) {
        fatalError()
        /*
        guard case .fieldList(let fields, _) = params else {
            preconditionFailure("\(#function) expects params to be of kind fieldList")
        }

        if fields.isEmpty {
            return ([], false)
        }

        var variableCount = 0
        for field in fields {
            guard case .field(let names, _, _) = field else {
                continue
            }

            variableCount += names.count
        }

        var isVariadic = false
        var variables: [Entity] = []
        for field in fields {
            guard case .field(let names, let typeExpr, _) = field else {
                continue
            }

            if case .ellipsis(let expr, _) = typeExpr {
                // TODO(vdka): unbox the type field of that AST node.
                if field == fields.last! {
                    isVariadic = true
                } else {
                    reportError("Invalid AST: Invalid variadic parameter", at: params)
                }
            }

            let type = checkType(typeExpr, namedType: nil)

            for nameNode in names {
                guard case .ident(let name, let location) = nameNode else { continue }

//                let entity = Entity(kind: .runtime, name: name, location: location, flags: [.used, .param], scope: scope, identifier: nameNode)
            }
        }
        */
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

            let d = context.decl!
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
