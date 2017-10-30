import LLVM

// sourcery:noinit
struct Checker {
    var file: SourceFile

    var context: Context

    init(file: SourceFile) {
        self.file = file
        context = Context(scope: file.scope, previous: nil)
    }

    // sourcery:noinit
    class Context {

        var scope: Scope
        var previous: Context?

        var function: Entity?
        var nearestFunction: Entity? {
            return function ?? previous?.nearestFunction
        }

        var expectedReturnType: ty.Tuple? = nil
        var nearestExpectedReturnType: ty.Tuple? {
            return expectedReturnType ?? previous?.nearestExpectedReturnType
        }
        var specializationCallNode: Call? = nil
        var nearestSpecializationCallNode: Call? {
            return specializationCallNode ?? previous?.nearestSpecializationCallNode
        }

        var nextCase: CaseClause?
        var nearestNextCase: CaseClause? {
            return nextCase ?? previous?.nearestNextCase
        }

        var switchLabel: Entity?
        var nearestSwitchLabel: Entity? {
            return switchLabel ?? previous?.nearestSwitchLabel
        }
        var inSwitch: Bool {
            return nearestSwitchLabel != nil
        }

        var loopBreakLabel: Entity?
        var nearestLoopBreakLabel: Entity? {
            return loopBreakLabel ?? previous?.nearestLoopBreakLabel
        }
        var inLoop: Bool {
            return nearestLoopBreakLabel != nil
        }

        var loopContinueLabel: Entity?
        var nearestLoopContinueLabel: Entity? {
            return loopContinueLabel ?? previous?.nearestLoopContinueLabel
        }

        var nearestLabel: Entity? {
            assert(loopBreakLabel == nil || switchLabel == nil)
            return loopBreakLabel ?? switchLabel ?? previous?.nearestLabel
        }

        init(scope: Scope, previous: Context?) {
            self.scope = scope
            self.previous = previous
        }
    }

    mutating func pushContext(owningNode: Node? = nil) {
        let newScope = Scope(parent: context.scope, owningNode: owningNode)
        context = Context(scope: newScope, previous: context)
    }

    mutating func popContext() {
        context = context.previous!
    }

    func declare(_ entity: Entity, scopeOwnsEntity: Bool = true) {
        let previous = context.scope.insert(entity, scopeOwnsEntity: scopeOwnsEntity)
        if let previous = previous, entity.file === previous.file {
            reportError("Invalid redeclaration of '\(previous.name)'", at: entity.ident.start)
            file.attachNote("Previous declaration here: \(file.position(for: previous.ident.start).description)")
        }
    }
}

extension Checker {

    mutating func checkFile() {
        for node in file.nodes {
            collect(topLevelStmt: node)
        }
        for node in file.nodes {
            check(topLevelStmt: node)
        }
    }

    mutating func collect(topLevelStmt stmt: TopLevelStmt) {
        switch stmt {
        case let i as Import:
            collect(import: i)
        case let l as Library:
            collect(library: l)
        case let f as Foreign:
            collect(foreignDecl: f.decl as! Declaration)
        case let d as DeclBlock:
            collect(declBlock: d)
        case let d as Declaration:
            collect(decl: d)
        case let using as Using:
            check(using: using)
        default:
            print("Warning: statement '\(stmt)' passed tharrough without getting checked")
        }
    }

    mutating func collect(declBlock b: DeclBlock) {
        for decl in b.decls {
            if b.isForeign {
                collect(foreignDecl: decl)
            } else {
                collect(decl: decl)
            }
        }
    }

    mutating func collect(import i: Import) {

        var entity: Entity?
        if let alias = i.alias {
            entity = newEntity(ident: alias, flags: .file)
        } else if !i.importSymbolsIntoScope {
            guard let name = i.resolvedName else {
                reportError("Cannot infer an import name for '\(i.path)'", at: i.path.start)
                file.attachNote("You will need to manually specify one")
                return
            }
            let ident = Ident(start: noPos, name: name, entity: nil, type: nil, conversion: nil, constant: nil)
            entity = newEntity(ident: ident, flags: .file)
        }

        // TODO: Ensure the import has been fully checked
        if i.importSymbolsIntoScope {
            for member in i.scope.members.values {
                guard !member.isFile && !member.isLibrary else {
                    continue
                }

                declare(member, scopeOwnsEntity: i.exportSymbolsOutOfScope)
            }
        } else if let entity = entity {
            entity.memberScope = i.scope
            entity.type = ty.File(memberScope: i.scope)
            declare(entity)
        }
    }

    mutating func collect(library l: Library) {

        guard let lit = l.path as? BasicLit, lit.token == .string else {
            reportError("Library path must be a string literal value", at: l.path.start)
            return
        }

        let path = lit.constant as! String

        l.resolvedName = l.alias?.name ?? pathToEntityName(path)

        // TODO: Use the Value system to resolve any string value.
        guard let name = l.resolvedName else {
            reportError("Cannot infer an import name for '\(path)'", at: l.path.start)
            file.attachNote("You will need to manually specify one")
            return
        }
        let ident = l.alias ?? Ident(start: noPos, name: name, entity: nil, type: nil, conversion: nil, constant: nil)
        let entity = newEntity(ident: ident, flags: .library)
        declare(entity)

        if path != "libc" && path != "llvm" {

            guard let linkpath = resolveLibraryPath(path, for: file.fullpath) else {
                reportError("Failed to resolve path for '\(path)'", at: l.path.start)
                return
            }
            file.package.linkedLibraries.insert(linkpath)
        }
    }

    mutating func collect(decl: Declaration) {
        if decl.isTest && !Options.instance.isTestMode {
            return
        }

        var entities: [Entity] = []

        for ident in decl.names {
            if ident.name == "_" {
                entities.append(Entity.anonymous)
                continue
            }

            let entity = newEntity(ident: ident)
            entity.declaration = decl
            ident.entity = entity
            entities.append(entity)
            declare(entity)
        }

        decl.entities = entities
        decl.declaringScope = context.scope
    }

    mutating func collect(foreignDecl d: Declaration) {
        // NOTE: Foreign declarations inforce singular names.
        let ident = d.names[0]
        if ident.name == "_" {
            return
        }

        let entity = newEntity(ident: ident, flags: d.isConstant ? [.constant, .foreign] : .foreign)
        entity.declaration = d
        ident.entity = entity
        declare(entity)
        d.entities = [entity]
    }
}


// MARK: Top Level Statements

extension Checker {

    mutating func check(topLevelStmt stmt: TopLevelStmt) {
        switch stmt {
        case is Using,
             is Import,
             is Library:
        break // we check these during collection.
        case let f as Foreign:
            let dependencies = check(foreignDecl: f.decl as! Declaration)
            f.dependsOn = dependencies
        case let d as Declaration:
            guard !d.checked else {
                return
            }

            if d.isTest && !Options.instance.isTestMode {
                return
            }

            let dependencies = check(decl: d)
            d.dependsOn = dependencies
            d.checked = true
        case let block as DeclBlock:
            let dependencies = check(declBlock: block)
            block.dependsOn = dependencies
        default:
            print("Warning: statement '\(stmt)' passed through without getting checked")
        }
    }

    /// - returns: The entities references by the statement
    mutating func check(stmt: Stmt) -> Set<Entity> {

        switch stmt {
        case is Empty:
            return []

        case let stmt as ExprStmt:
            let operand = check(expr: stmt.expr)
            switch stmt.expr {
            case let call as Call:
                switch call.checked! {
                case .call, .specializedCall:
                    guard let fnNode = (call.fun.type as? ty.Function)?.node, fnNode.isDiscardable || operand.type is ty.Void else {
                        fallthrough
                    }
                    // TODO: Report unused returns on non discardables
                default:
                    break
                }

            default:
                if !(operand.type is ty.Invalid) {
                    reportError("Expression of type \(operand.type) is unused", at: stmt.start)
                }
            }
            return operand.dependencies
        case let decl as Declaration:
            return check(decl: decl)
        case let block as DeclBlock:
            return check(declBlock: block)
        case let assign as Assign:
            return check(assign: assign)
        case let block as Block:
            var dependencies: Set<Entity> = []
            pushContext()
            for stmt in block.stmts {
                let deps = check(stmt: stmt)
                dependencies.formUnion(deps)
            }
            popContext()
            return dependencies
        case let using as Using:
            check(using: using)
            return []

        case let ret as Return:
            return check(return: ret)

        case let d as Defer:
            return check(defer: d)

        case let fór as For:
            return check(for: fór)

        case let forIn as ForIn:
            return check(forIn: forIn)

        case let íf as If:
            return check(if: íf)

        case let s as Switch:
            return check(switch: s)

        case let b as Branch:
            check(branch: b)
            return []

        default:
            print("Warning: statement '\(stmt)' passed through without getting checked")
            return []
        }
    }

    mutating func check(decl: Declaration) -> Set<Entity> {
        let dependencies: Set<Entity>

        // only has an effect if there is a declaring scope
        // Set the scope to the one the declaration occured in, this way if,
        //   we are forced to check something declared later in the file it's
        //   declared in the correct scope.
        let prevScope = context.scope
        defer {
            context.scope = prevScope
        }
        if let declaringScope = decl.declaringScope {
            context.scope = declaringScope
        }

        // Create the entities for the declaration
        if decl.entities == nil {
            var entities: [Entity] = []
            entities.reserveCapacity(decl.names.count)
            for ident in decl.names {
                if ident.name == "_" {
                    ident.entity = Entity.anonymous
                } else {
                    ident.entity = newEntity(ident: ident)
                    declare(ident.entity)
                }
                entities.append(ident.entity)
            }
            decl.entities = entities
        }

        if decl.isConstant {
            dependencies = check(constantDecl: decl)
        } else {
            dependencies = check(variableDecl: decl)
        }
        decl.checked = true
        return dependencies
    }

    mutating func check(constantDecl decl: Declaration) -> Set<Entity> {
        var dependencies: Set<Entity> = []

        guard decl.names.count == 1 else {
            reportError("Constant declarations must declare at most a single Entity", at: decl.names[1].start)
            decl.entities.forEach({ $0.type = ty.invalid })
            return dependencies
        }

        var expectedType: Type?
        if let explicitType = decl.explicitType {
            let operand = check(expr: explicitType)
            dependencies.formUnion(operand.dependencies)
            expectedType = lowerFromMetatype(operand.type, atNode: explicitType)
        }

        let value = decl.values[0]
        let ident = decl.names[0]

        defer {
            context.function = nil
        }
        if let value = value as? FuncLit, !value.explicitType.isPolymorphic {
            // setup a stub function so that recursive functions check properly
            context.function = ident.entity
            let operand = check(funcType: value.explicitType)
            ident.entity.type = operand.type.lower()
        } else if value is StructType || value is PolyStructType || value is UnionType || value is VariantType || value is EnumType {
            // declare a stub type, collect all member declarations
            let stub = ty.Named(entity: ident.entity, base: nil)
            ident.entity.type = ty.Metatype(instanceType: stub)
        }
        let operand = check(expr: value, desiredType: expectedType)
        dependencies.formUnion(operand.dependencies)

        ident.entity.constant = operand.constant
        ident.constant = operand.constant
        ident.entity.linkname = decl.linkname

        ident.entity.flags.insert(.constant)
        ident.entity.flags.insert(.checked)

        var type = operand.type!
        if let expectedType = expectedType, !convert(type, to: expectedType, at: value) {
            reportError("Cannot convert \(operand) to specified type '\(expectedType)'", at: value.start)
            return dependencies
        }

        if type is ty.Tuple {
            assert((type as! ty.Tuple).types.count != 1)
            reportError("Multiple value \(value) where single value was expected", at: value.start)
            return dependencies
        }

        if var metatype = type as? ty.Metatype {
            ident.entity.flags.insert(.type)
            guard let baseType = baseType(metatype.instanceType) as? NamableType else {
                reportError("The type '\(metatype.instanceType)' is not aliasable", at: value.start)
                return dependencies
            }

            if let existing = (ident.entity.type as? ty.Metatype)?.instanceType as? ty.Named {
                // For Structs we have previously defined a 'stub' named version, here we want to 'fulfill' that stub
                //  by setting the base type for that named typed
                existing.base = baseType
            }
            metatype.instanceType = ty.Named(entity: ident.entity, base: baseType)
            type = metatype
        }

        ident.entity.type = type

        return dependencies
    }

    mutating func check(variableDecl decl: Declaration) -> Set<Entity> {
        var dependencies: Set<Entity> = []

        var expectedType: Type?
        if let explicitType = decl.explicitType {
            let operand = check(expr: explicitType)
            dependencies.formUnion(operand.dependencies)
            expectedType = lowerFromMetatype(operand.type, atNode: explicitType)
        }

        // Handle linkname directive
        if let linkname = decl.linkname {
            decl.names[0].entity.linkname = linkname
            if decl.names.count > 1 {
                reportError("Linkname cannot be used on a declaration of multiple entities", at: decl.start)
            }
        }

        // handle uninitialized variable declaration `x, y: i32`
        if decl.values.isEmpty {
            assert(expectedType != nil)
            for ident in decl.names {
                ident.entity.flags.insert(.checked)
                ident.entity.type = expectedType
            }

            // Because we must have types set for later, we use the expected type even if it is illegal
            if let type = expectedType as? ty.Array, type.length == nil {
                reportError("Implicit-length array must have an initial value", at: decl.explicitType!.start)
                return dependencies
            }
            if let type = expectedType as? ty.Function {
                reportError("Variables of a function type must be initialized", at: decl.start)
                file.attachNote("If you want an uninitialized function pointer use *\(type) instead")
                return dependencies
            }
            return dependencies
        }

        // handle multi-value call variable expressions
        if decl.names.count != decl.values.count {
            guard decl.values.count == 1, let call = decl.values[0] as? Call else {
                reportError("Assigment count mismatch \(decl.names.count) = \(decl.values.count)", at: decl.start)
                return dependencies
            }
            guard expectedType == nil else {
                reportError("Explicit types are prohibited when calling a multiple-value function", at: decl.explicitType!.start)
                return dependencies
            }
            let operand = check(call: call)
            dependencies.formUnion(operand.dependencies)
            if let tuple = operand.type as? ty.Tuple {
                guard decl.names.count == tuple.types.count else {
                    reportError("Assignment count mismatch \(decl.names.count) = \(tuple.types.count)", at: decl.start)
                    return dependencies
                }
                for (ident, type) in zip(decl.names, tuple.types) {
                    if ident.entity === Entity.anonymous {
                        continue
                    }
                    ident.entity.flags.insert(.checked)
                    ident.entity.type = type
                }
                return dependencies
            }
            decl.names[0].entity.flags.insert(.checked)
            decl.names[0].entity.type = operand.type
            return dependencies
        }

        // At this point we have a simple declaration of 1 or more entities with matching values
        for (ident, value) in zip(decl.names, decl.values) {
            let operand = check(expr: value, desiredType: expectedType)
            dependencies.formUnion(operand.dependencies)

            if let expectedType = expectedType, !convert(operand.type, to: expectedType, at: value) {
                reportError("Cannot convert \(operand) to specified type '\(expectedType)'", at: value.start)
            }

            if ident.entity === Entity.anonymous {
                continue
            }

            guard !isMetatype(operand.type) else {
                reportError("\(operand) is not an expression", at: value.start)
                continue
            }

            ident.entity.flags.insert(.checked)
            ident.entity.type = operand.type
        }

        return dependencies
    }

    /// - returns: The entities this declaration depends on (not the entities declared)
    mutating func check(declBlock b: DeclBlock) -> Set<Entity> {
        var dependencies: Set<Entity> = []
        for decl in b.decls {
            guard decl.names.count == 1 else {
                reportError("Grouped declarations must be singular", at: decl.names[1].start)
                continue
            }
            decl.callconv = decl.callconv ?? b.callconv

            if b.isForeign {
                let deps = check(foreignDecl: decl)
                dependencies.formUnion(deps)

                let entity = decl.entities[0]
                entity.linkname = decl.linkname ?? (b.linkprefix ?? "") + entity.name
            } else {
                let deps = check(decl: decl)
                dependencies.formUnion(deps)

                let entity = decl.entities[0]
                if decl.linkname != nil || b.linkprefix != nil {
                    entity.linkname = decl.linkname ?? (b.linkprefix ?? "") + entity.name
                }
            }
        }
        return dependencies
    }

    /// - returns: The entities this declaration depends on (not the entities declared)
    mutating func check(foreignDecl d: Declaration) -> Set<Entity> {
        let ident = d.names[0]

        if d.callconv == nil {
            d.callconv = "c"
        }

        if !context.scope.isFile && !context.scope.isPackage {
            if ident.name == "_" {
                ident.entity = Entity.anonymous
                // throws error below
            } else {
                let entity = newEntity(ident: ident, flags: d.isConstant ? [.constant, .foreign] : .foreign)
                ident.entity = entity
                declare(entity)
                d.entities = [entity]
            }
        }

        if ident.entity === Entity.anonymous {
            reportError("The dispose identifer is not a permitted name in foreign declarations", at: ident.start)
            return []
        }

        // only 2 forms allowed by the parser `i: ty` or `i :: ty`
        //  these represent a foreign variable and a foreign constant respectively.
        // In both cases these are no values, just an explicitType is set. No values.
        let operand = check(expr: d.explicitType!)
        var type = lowerFromMetatype(operand.type, atNode: d.explicitType!)

        if d.isConstant {
            if let pointer = type as? ty.Pointer, pointer.pointeeType is ty.Function {
                type = pointer.pointeeType
            }
        }
        ident.entity.flags.insert(.checked)
        ident.entity.type = type

        return operand.dependencies
    }

    /// - returns: The entities this declaration depends on
    mutating func check(assign: Assign) -> Set<Entity> {
        var dependencies: Set<Entity> = []

        if assign.rhs.count == 1 && assign.lhs.count > 1, let call = assign.rhs[0] as? Call {
            let operand = check(call: call)
            dependencies.formUnion(operand.dependencies)

            let types = (operand.type as! ty.Tuple).types

            for (lhs, type) in zip(assign.lhs, types) {
                let lhsOperand = check(expr: lhs)
                dependencies.formUnion(lhsOperand.dependencies)

                guard lhsOperand.mode == .addressable || lhsOperand.mode == .assignable else {
                    reportError("Cannot assign to \(lhsOperand)", at: lhs.start)
                    continue
                }
                guard type == lhsOperand.type else {
                    reportError("Cannot assign \(operand) to \(lhsOperand)", at: call.start)
                    continue
                }
            }
        } else {

            for (lhs, rhs) in zip(assign.lhs, assign.rhs) {
                let lhsOperand = check(expr: lhs)
                let rhsOperand = check(expr: rhs, desiredType: lhsOperand.type)
                dependencies.formUnion(lhsOperand.dependencies)
                dependencies.formUnion(rhsOperand.dependencies)

                guard lhsOperand.mode == .addressable else {
                    reportError("Cannot assign to \(lhsOperand)", at: lhs.start)
                    continue
                }
                guard convert(rhsOperand.type, to: lhsOperand.type, at: rhs) else {
                    reportError("Cannot assign \(rhsOperand) to \(lhsOperand)", at: rhs.start)
                    continue
                }
            }

            if assign.lhs.count != assign.rhs.count {
                reportError("Assignment count missmatch \(assign.lhs.count) = \(assign.rhs.count)", at: assign.start)
            }
        }
        return dependencies
    }

    mutating func check(using: Using) {
        func declare(_ entity: Entity) {
            let previous = context.scope.insert(entity, scopeOwnsEntity: false)
            if let previous = previous {
                reportError("Use of 'using' resulted in name collision for the name '\(previous.name)'", at: entity.ident.start)
                file.attachNote("Previously declared here: \(previous.ident.start)")
            }
        }

        let operand = check(expr: using.expr)

        switch operand.type {
        case let type as ty.File:
            for entity in type.memberScope.members.values {
                declare(entity)
            }
        case let type as ty.Struct:
            for field in type.fields.orderedValues {
                let entity = newEntity(ident: field.ident, type: field.type, flags: .field, owningScope: context.scope)
                declare(entity)
            }
        case let meta as ty.Metatype:
            guard let type = lowerFromMetatype(meta, atNode: using.expr) as? ty.Enum else {
                fallthrough
            }

            for c in type.cases.orderedValues {
                let entity = newEntity(ident: c.ident, type: type, flags: .field, owningScope: context.scope)
                entity.constant = c.constant ?? UInt64(c.number)
                declare(entity)
            }
        default:
            reportError("using is invalid on \(operand)", at: using.expr.start)
        }
    }

    mutating func check(defer d: Defer) -> Set<Entity> {
        pushContext(owningNode: d); defer {
            popContext()
        }
        return check(stmt: d.stmt)
    }
}


// MARK: Statements

extension Checker {

    mutating func check(branch: Branch) {
        switch branch.token {
        case .break:
            let target: Entity
            if let label = branch.label {
                guard let entity = context.scope.lookup(label.name) else {
                    reportError("Use of undefined identifer '\(label)'", at: label.start)
                    return
                }
                target = entity
            } else {
                guard let entity = context.nearestLabel else {
                    reportError("break outside of loop or switch", at: branch.start)
                    return
                }
                target = entity
            }
            branch.target = target
        case .continue:
            let target: Entity
            if let label = branch.label {
                guard let entity = context.scope.lookup(label.name) else {
                    reportError("Use of undefined identifer '\(label)'", at: label.start)
                    return
                }
                target = entity
            } else {
                guard let entity = context.nearestLoopContinueLabel else {
                    reportError("break outside of loop", at: branch.start)
                    return
                }
                target = entity
            }
            branch.target = target
        case .fallthrough:
            guard context.inSwitch else {
                reportError("fallthrough outside of switch", at: branch.start)
                return
            }
            guard let target = context.nearestNextCase?.label else {
                reportError("fallthrough cannot be used without a next case", at: branch.start)
                return
            }
            branch.target = target
        default:
            fatalError()
        }
    }

    mutating func check(return ret: Return) -> Set<Entity> {
        let expectedReturn = context.nearestExpectedReturnType!

        var isVoidReturn = false
        if expectedReturn.types.count == 1 && isVoid(expectedReturn.types[0]) {
            isVoidReturn = true
        }

        var dependencies: Set<Entity> = []
        for (value, expected) in zip(ret.results, expectedReturn.types) {
            let operand = check(expr: value, desiredType: expected)
            dependencies.formUnion(operand.dependencies)

            if !convert(operand.type, to: expected, at: value) {
                if isVoidReturn {
                    reportError("Void function should not return a value", at: value.start)
                    return dependencies
                } else {
                    reportError("Cannot convert \(operand) to expected type '\(expected)'", at: value.start)
                }
            }
        }

        if ret.results.count < expectedReturn.types.count, let first = expectedReturn.types.first, !isVoid(first) {
            reportError("Not enough arguments to return", at: ret.start)
        } else if ret.results.count > expectedReturn.types.count {
            reportError("Too many arguments to return", at: ret.start)
        }
        return dependencies
    }

    mutating func check(for fór: For) -> Set<Entity> {
        var dependencies: Set<Entity> = []
        pushContext()
        defer {
            popContext()
        }

        let breakLabel = Entity.makeAnonLabel()
        let continueLabel = Entity.makeAnonLabel()
        fór.breakLabel = breakLabel
        fór.continueLabel = continueLabel
        context.loopBreakLabel = breakLabel
        context.loopContinueLabel = continueLabel

        if let initializer = fór.initializer {
            let deps = check(stmt: initializer)
            dependencies.formUnion(deps)
        }

        if let cond = fór.cond {
            let operand = check(expr: cond, desiredType: ty.bool)
            if !convert(operand.type, to: ty.bool, at: cond) {
                reportError("Cannot convert \(operand) to expected type '\(ty.bool)'", at: cond.start)
            }
        }

        if let step = fór.step {
            let deps = check(stmt: step)
            dependencies.formUnion(deps)
        }

        let deps = check(stmt: fór.body)
        dependencies.formUnion(deps)
        return dependencies
    }

    mutating func check(forIn: ForIn) -> Set<Entity> {
        var dependencies: Set<Entity> = []
        pushContext()
        defer {
            popContext()
        }

        let breakLabel = Entity.makeAnonLabel()
        let continueLabel = Entity.makeAnonLabel()
        forIn.breakLabel =  breakLabel
        forIn.continueLabel = continueLabel
        context.loopBreakLabel = breakLabel
        context.loopContinueLabel = continueLabel

        if forIn.names.count > 2 {
            reportError("A `for in` statement can only have 1 or 2 declarations", at: forIn.names.last!.start)
        }

        let operand = check(expr: forIn.aggregate)
        dependencies.formUnion(operand.dependencies)
        guard canSequence(operand.type) else {
            forIn.aggregate.type = ty.invalid
            reportError("Cannot create a sequence for \(operand)", at: forIn.aggregate.start)
            return dependencies
        }

        let elementType: Type
        switch baseType(operand.type) {
        case let array as ty.Array:
            elementType = array.elementType
            forIn.checked = .array(array.length)
        case let slice as ty.Slice:
            elementType = slice.elementType
            forIn.checked = .structure
        case is ty.KaiString:
            elementType = ty.u8
            forIn.checked = .structure
        default:
            preconditionFailure()
        }

        let element = forIn.names[0]
        let elEntity = newEntity(ident: element, type: elementType)
        declare(elEntity)
        forIn.element = elEntity

        if let index = forIn.names[safe: 1] {
            let iEntity = newEntity(ident: index, type: ty.i64)
            declare(iEntity)
            forIn.index = iEntity
        }

        let deps = check(stmt: forIn.body)
        dependencies.formUnion(deps)
        return dependencies
    }

    mutating func check(if iff: If) -> Set<Entity> {
        var dependencies: Set<Entity> = []

        pushContext()
        let operand = check(expr: iff.cond, desiredType: ty.bool)
        dependencies.formUnion(operand.dependencies)
        if !convert(operand.type, to: ty.bool, at: iff.cond) {
            reportError("Cannot convert \(operand) to expected type '\(ty.bool)'", at: iff.cond.start)
        }

        let deps = check(stmt: iff.body)
        popContext()
        dependencies.formUnion(deps)
        if let els = iff.els {
            pushContext()
            let deps = check(stmt: els)
            popContext()
            dependencies.formUnion(deps)
        }
        return dependencies
    }

    mutating func check(switch sw: Switch) -> Set<Entity> {
        var dependencies: Set<Entity> = []
        pushContext()
        defer {
            popContext()
        }

        let label = Entity.makeAnonLabel()
        sw.label = label
        context.switchLabel = label

        var type: Type?
        if let match = sw.match {
            let operand = check(expr: match)
            dependencies.formUnion(operand.dependencies)

            type = operand.type
            guard isInteger(operand.type) || isEnum(operand.type) else {
                reportError("Can only switch on integer and enum types", at: match.start)
                return dependencies
            }
        }

        var seenDefault = false

        for c in sw.cases {
            c.label = Entity.makeAnonLabel()
        }

        for (c, nextCase) in sw.cases.enumerated().map({ ($0.element, sw.cases[safe: $0.offset + 1]) }) {
            if let match = c.match {
                if let desiredType = type {
                    let operand = check(expr: match, desiredType: desiredType)
                    dependencies.formUnion(operand.dependencies)

                    guard convert(operand.type, to: desiredType, at: match) else {
                        reportError("Cannot convert \(operand) to expected type '\(desiredType)'", at: match.start)
                        continue
                    }
                } else {
                    let operand = check(expr: match, desiredType: ty.bool)
                    dependencies.formUnion(operand.dependencies)

                    guard convert(operand.type, to: ty.bool, at: match) else {
                        reportError("Cannot convert \(operand) to expected type '\(ty.bool)'", at: match.start)
                        continue
                    }
                }
            } else if seenDefault {
                reportError("Duplicate default cases", at: c.start)
            } else {
                seenDefault = true
            }

            context.nextCase = nextCase
            pushContext()
            let deps = check(stmt: c.block)
            popContext()
            dependencies.formUnion(deps)
        }

        context.nextCase = nil
        return dependencies
    }
}


// MARK: Expressions

extension Checker {

    mutating func check(expr: Expr, desiredType: Type? = nil) -> Operand {

        switch expr {
        case let expr as Nil:
            // let this fall through until later
            expr.type = desiredType ?? ty.invalid
            if let desiredType = desiredType {
                return Operand(mode: .computed, expr: expr, type: desiredType, constant: expr, dependencies: [])
            }
            return Operand(mode: .computed, expr: expr, type: ty.untypedNil, constant: expr, dependencies: [])

            // TODO: Should the following errors be used?
            /*
            guard let desiredType = desiredType else {
                reportError("'nil' requires a contextual type", at: expr.start)
                return ty.invalid
            }
            guard desiredType is ty.Pointer else {
                reportError("'nil' is not convertable to '\(desiredType)'", at: expr.start)
                return ty.invalid
            }
            expr.type = desiredType
            return desiredType
            */

        case let ident as Ident:
            return check(ident: ident, desiredType: desiredType)

        case let lit as BasicLit:
            return check(basicLit: lit, desiredType: desiredType)

        case let lit as CompositeLit:
            return check(compositeLit: lit, desiredType: desiredType)

        case let fn as FuncLit:
            return check(funcLit: fn)

        case let fn as FuncType:
            return check(funcType: fn)

        case let polyType as PolyType:
            let type = check(polyType: polyType)
            return Operand(mode: .type, expr: expr, type: type, constant: nil, dependencies: [])

        case let variadic as VariadicType:
            return check(expr: variadic.explicitType)

        case let pointer as PointerType:
            let operand = check(expr: pointer.explicitType)
            let pointee = lowerFromMetatype(operand.type, atNode: pointer.explicitType)
            // TODO: If this cannot be lowered we should not that `<` is used for deref
            let type = ty.Pointer(pointeeType: pointee)
            pointer.type = ty.Metatype(instanceType: type)
            return Operand(mode: .type, expr: expr, type: pointer.type, constant: nil, dependencies: operand.dependencies)

        case let array as ArrayType:
            let elementOperand = check(expr: array.explicitType)
            let elementType = lowerFromMetatype(elementOperand.type, atNode: array)
            var dependencies: Set<Entity> = []
            var length: Int?
            if let lengthExpr = array.length {
                let lengthOperand = check(expr: lengthExpr)
                guard let len = lengthOperand.constant as? UInt64 else {
                    reportError("Currently, only integer literals are allowed for array length", at: lengthExpr.start)
                    return Operand.invalid
                }

                length = Int(len)

                dependencies = elementOperand.dependencies.union(lengthOperand.dependencies)
            }

            let type = ty.Array(length: length, elementType: elementType)
            array.type = ty.Metatype(instanceType: type)
            return Operand(mode: .type, expr: expr, type: array.type, constant: nil, dependencies: dependencies)

        case let array as SliceType:
            let elementOperand = check(expr: array.explicitType)
            let elementType = lowerFromMetatype(elementOperand.type, atNode: array)

            let type = ty.Slice(elementType: elementType)
            array.type = ty.Metatype(instanceType: type)
            return Operand(mode: .type, expr: expr, type: array.type, constant: nil, dependencies: elementOperand.dependencies)

        case let vector as VectorType:
            let elementOperand = check(expr: vector.explicitType)
            let elementType = lowerFromMetatype(elementOperand.type, atNode: vector)

            guard canVector(elementType) else {
                reportError("Vector only supports primitive data types", at: vector.explicitType.start)
                vector.type = ty.invalid
                return Operand.invalid
            }

            let sizeOperand = check(expr: vector.size)
            guard let size = sizeOperand.constant as? UInt64 else {
                reportError("Cannot convert '\(sizeOperand)' to a constant Integer", at: vector.size.start)
                vector.type = ty.invalid
                return Operand.invalid
            }
            let type = ty.Vector(size: Int(size), elementType: elementType)
            vector.type = ty.Metatype(instanceType: type)

            let dependencies = elementOperand.dependencies.union(sizeOperand.dependencies)
            return Operand(mode: .type, expr: expr, type: vector.type, constant: nil, dependencies: dependencies)

        case let s as StructType:
            return check(struct: s)

        case let s as PolyStructType:
            return check(polyStruct: s)

        case let u as UnionType:
            return check(union: u)

        case let v as VariantType:
            return check(variant: v)

        case let e as EnumType:
            return check(enumType: e)

        case let paren as Paren:
            return check(expr: paren.element, desiredType: desiredType)

        case let unary as Unary:
            return check(unary: unary, desiredType: desiredType)

        case let binary as Binary:
            return check(binary: binary, desiredType: desiredType)

        case let ternary as Ternary:
            return check(ternary: ternary, desiredType: desiredType)

        case let selector as Selector:
            return check(selector: selector, desiredType: desiredType)

        case let s as Subscript:
            return check(subscript: s)

        case let s as Slice:
            return check(slice: s)

        case let call as Call:
            return check(call: call)

        case let cast as Cast:
            return check(cast: cast)

        case let autocast as Autocast:
            return check(autocast: autocast, desiredType: desiredType)

        case let l as LocationDirective:
            return check(locationDirective: l, desiredType: desiredType)

        default:
            print("Warning: expression '\(expr)' passed through without getting checked")
            expr.type = ty.invalid
            return Operand.invalid
        }
    }

    @discardableResult
    mutating func check(ident: Ident, desiredType: Type? = nil) -> Operand {
        guard let entity = context.scope.lookup(ident.name) else {
            reportError("Use of undefined identifier '\(ident)'", at: ident.start)
            ident.entity = Entity.invalid
            ident.type = ty.invalid
            return Operand.invalid
        }
        guard !entity.isLibrary else {
            reportError("Cannot use library as expression", at: ident.start)
            ident.entity = Entity.invalid
            ident.type = ty.invalid
            return Operand.invalid
        }
        ident.entity = entity
        if entity.isConstant {
            ident.constant = entity.constant
        }

        assert(entity.type != nil || !entity.isChecked, "Either we have a type or the entity is yet to be checked")
        var type = entity.type
        if entity.type == nil {
            check(topLevelStmt: entity.declaration!)
            assert(entity.isChecked && entity.type != nil)
            type = entity.type
        }

        if let desiredType = desiredType, isUntypedNumber(entity.type!) {
            if constrainUntyped(type!, to: desiredType) {
                ident.conversion = (from: entity.type!, to: desiredType)
                ident.type = desiredType
                return Operand(mode: entity.isType ? .type : .addressable, expr: ident, type: desiredType, constant: entity.constant, dependencies: [entity])
            }
        }
        ident.type = type

        let mode: Operand.Mode
        if entity.isFile {
            mode = .file
        } else if entity.isLabel {
            mode = .computed
        } else if entity.isType {
            mode = .type
        } else if entity.isBuiltin && (entity.name == "true" || entity.name == "false") {
            mode = .computed
        } else {
            mode = .addressable
        }

        return Operand(mode: mode, expr: ident, type: type, constant: entity.constant, dependencies: [entity])
    }

    @discardableResult
    mutating func check(basicLit lit: BasicLit, desiredType: Type?) -> Operand {
        switch lit.token {
        case .int:
            switch lit.text.prefix(2) {
            case "0x":
                let text = String(lit.text.dropFirst(2))
                lit.constant = UInt64(text, radix: 16)!
            case "0o":
                let text = String(lit.text.dropFirst(2))
                lit.constant = UInt64(text, radix: 8)!
            case "0b":
                let text = String(lit.text.dropFirst(2))
                lit.constant = UInt64(text, radix: 2)!
            default:
                lit.constant = UInt64(lit.text, radix: 10)!
            }
            if let desiredType = desiredType, isInteger(desiredType) {
                lit.type = desiredType
            } else if let desiredType = desiredType, isFloatingPoint(desiredType) {
                lit.type = desiredType
                lit.constant = Double(lit.constant as! UInt64)
            } else {
                lit.type = ty.untypedInteger
            }
        case .float:
            lit.constant = Double(lit.text)!
            if let desiredType = desiredType, isFloatingPoint(desiredType) {
                lit.type = desiredType
            } else {
                lit.type = ty.untypedFloat
            }
        case .string:
            lit.type = ty.string
        default:
            lit.type = ty.invalid
        }
        return Operand(mode: .computed, expr: lit, type: lit.type, constant: lit.constant, dependencies: [])
    }

    @discardableResult
    mutating func check(compositeLit lit: CompositeLit, desiredType: Type?) -> Operand {
        var dependencies: Set<Entity> = []
        let operand: Operand?
        let type: Type?
        if let explicitType = lit.explicitType {
            operand = check(expr: explicitType)
            dependencies.formUnion(operand!.dependencies)
            type = lowerFromMetatype(operand!.type, atNode: explicitType)
            lit.type = type
        } else if let desiredType = desiredType {
            operand = nil
            type = desiredType
        } else {
            lit.type = ty.invalid
            reportError("Unable to determine type for composite literal", at: lit.start)
            return Operand.invalid
        }

        switch baseType(type!) {
        case let s as ty.Struct:
            if lit.elements.count > s.fields.count {
                reportError("Too many values in struct initializer", at: lit.elements[s.fields.count].start)
            }
            for (el, field) in zip(lit.elements, s.fields.orderedValues) {

                if let key = el.key {
                    guard let ident = key as? Ident else {
                        reportError("Expected identifier for key in composite literal for struct", at: key.start)
                        // bail, likely everything is wrong
                        return Operand(mode: .invalid, expr: lit, type: type, constant: nil, dependencies: operand?.dependencies ?? [])
                    }
                    guard let field = s.fields[ident.name] else {
                        reportError("Unknown field '\(ident)' for struct '\(type!)'", at: ident.start)
                        continue
                    }

                    el.structField = field
                    let operand = check(expr: el.value, desiredType: field.type)
                    dependencies.formUnion(operand.dependencies)

                    el.type = operand.type
                    guard convert(el.type, to: field.type, at: el.value) else {
                        reportError("Cannot convert element \(operand) to expected type '\(field.type)'", at: el.value.start)
                        continue
                    }
                } else {
                    el.structField = field
                    let operand = check(expr: el.value, desiredType: field.type)
                    dependencies.formUnion(operand.dependencies)

                    el.type = operand.type
                    guard convert(el.type, to: field.type, at: el.value) else {
                        reportError("Cannot convert element \(operand) to expected type '\(field.type)'", at: el.value.start)
                        continue
                    }
                }
            }
            lit.type = type
            return Operand(mode: .computed, expr: lit, type: type, constant: nil, dependencies: dependencies)

        case var type as ty.Array:
            if type.length != nil {
                if lit.elements.count != type.length {
                    reportError("Element count (\(lit.elements.count)) does not match array length (\(type.length))", at: lit.start)
                }
            } else {
                // NOTE: implicit array length
                type.length = lit.elements.count
            }

            for el in lit.elements {
                let operand = check(expr: el.value, desiredType: type.elementType)
                dependencies.formUnion(operand.dependencies)

                el.type = operand.type
                guard convert(el.type, to: type.elementType, at: el.value) else {
                    reportError("Cannot convert element \(operand) to expected type '\(type.elementType)'", at: el.value.start)
                    continue
                }
            }

            lit.type = type
            return Operand(mode: .computed, expr: lit, type: type, constant: nil, dependencies: dependencies)

        case let slice as ty.Slice:
            for el in lit.elements {
                let operand = check(expr: el.value, desiredType: slice.elementType)
                dependencies.formUnion(operand.dependencies)

                el.type = operand.type
                guard convert(el.type, to: slice.elementType, at: el.value) else {
                    reportError("Cannot convert element \(operand) to expected type '\(slice.elementType)'", at: el.value.start)
                    continue
                }
            }

            lit.type = slice
            return Operand(mode: .computed, expr: lit, type: slice, constant: nil, dependencies: dependencies)

        case let type as ty.Vector:
            if lit.elements.count != type.size {
                reportError("Element count (\(lit.elements.count)) does not match vector size (\(type.size))", at: lit.start)
            }

            for el in lit.elements {
                let operand = check(expr: el.value, desiredType: type.elementType)
                dependencies.formUnion(operand.dependencies)

                el.type = operand.type
                guard convert(el.type, to: type.elementType, at: el.value) else {
                    reportError("Cannot convert element \(operand) to expected type '\(type.elementType)'", at: el.value.start)
                    continue
                }
            }

            lit.type = type
            return Operand(mode: .computed, expr: lit, type: type, constant: nil, dependencies: dependencies)

        default:
            reportError("Invalid type for composite literal", at: lit.start)
            lit.type = ty.invalid
            return Operand.invalid
        }
    }

    @discardableResult
    mutating func check(polyType: PolyType) -> Type {
        if polyType.type != nil {
            // Do not redeclare any poly types which have been checked before.
            return polyType.type
        }
        switch polyType.explicitType {
        case let ident as Ident:
            let entity = newEntity(ident: ident, type: ty.invalid, flags: .implicitType)
            declare(entity)
            var type: Type
            type = ty.Polymorphic(entity: entity, specialization: Ref(nil))
            type = ty.Metatype(instanceType: type)
            entity.type = type
            polyType.type = type
            return type
        case is ArrayType, is SliceType:
            fatalError("TODO")
        default:
            reportError("Unsupported polytype", at: polyType.start)
            // TODO: Better error for unhandled types here.
            polyType.type = ty.invalid
            return ty.invalid
        }
    }

    @discardableResult
    mutating func check(funcLit fn: FuncLit) -> Operand {
        var dependencies: Set<Entity> = []

        var needsSpecialization = false
        var typeFlags: ty.Function.Flags = .none
        var inputs: [Type] = []
        var outputs: [Type] = []

        if !fn.isSpecialization {
            var params: [Entity] = []
            pushContext()

            // FIXME: @unimplemented
            assert(fn.explicitType.labels != nil, "Currently function literals without argument names are disallowed")

            for (label, param) in zip(fn.explicitType.labels!, fn.explicitType.params) {
                if fn.isSpecialization && param.type != nil && !isPolymorphic(param.type) {
                    // The polymorphic parameters type has been set by the callee
                    inputs.append(param.type)
                    continue
                }

                needsSpecialization = needsSpecialization || param.isPolymorphic

                let operand = check(expr: param)
                var type = lowerFromMetatype(operand.type, atNode: param)
                let entity = newEntity(ident: label, type: type, flags: param.isPolymorphic ? .polyParameter : .parameter)
                declare(entity)
                params.append(entity)
                dependencies.formUnion(operand.dependencies)

                if let paramType = param as? VariadicType {
                    fn.flags.insert(paramType.isCvargs ? .cVariadic : .variadic)
                    typeFlags.insert(paramType.isCvargs ? .cVariadic : .variadic)
                    if paramType.isCvargs && isAnyy(type) {
                        type = ty.cvargAny
                    }
                }

                inputs.append(type)
            }
            fn.params = params

            for result in fn.explicitType.results {
                let operand = check(expr: result)
                dependencies.formUnion(operand.dependencies)

                let type = lowerFromMetatype(operand.type, atNode: result)

                outputs.append(type)
            }
        } else { // fn.isSpecialization
            inputs = fn.explicitType.params
                .map({ lowerFromMetatype($0.type, atNode: $0) })
                .map(lowerSpecializedPolymorphics)
            outputs = fn.explicitType.results
                .map({ lowerFromMetatype($0.type, atNode: $0) })
                .map(lowerSpecializedPolymorphics)
        }

        let result = ty.Tuple.make(outputs)

        let prevReturnType = context.expectedReturnType
        context.expectedReturnType = result
        if !needsSpecialization { // FIXME: We need to partially check polymorphics to determine dependencies, Do we?
            let deps = check(stmt: fn.body)
            dependencies.formUnion(deps)
        }
        context.expectedReturnType = prevReturnType

        // TODO: Only allow single void return
        if isVoid(result.types[0]) {
            if fn.isDiscardable {
                reportError("#discardable on void returning function is superflous", at: fn.start)
            }
        } else {
            if !allBranchesRet(fn.body.stmts) {
                reportError("function missing return", at: fn.start)
            }
        }

        if needsSpecialization && !fn.isSpecialization {
            typeFlags.insert(.polymorphic)
            fn.type = ty.Function(node: fn, labels: fn.labels, params: inputs, returnType: result, flags: .polymorphic)
            fn.checked = .polymorphic(declaringScope: context.scope.parent!, specializations: [])
        } else {
            fn.type = ty.Function(node: fn, labels: fn.labels, params: inputs, returnType: result, flags: typeFlags)
            fn.checked = .regular(context.scope)
        }

        if !fn.isSpecialization {
            popContext()
        }
        return Operand(mode: .computed, expr: fn, type: fn.type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(funcType fn: FuncType) -> Operand {
        var dependencies: Set<Entity> = []

        var typeFlags: ty.Function.Flags = .none
        var params: [Type] = []
        for param in fn.params {
            let operand = check(expr: param)
            dependencies.formUnion(operand.dependencies)

            var type = lowerFromMetatype(operand.type, atNode: param)

            if let param = param as? VariadicType {
                fn.flags.insert(param.isCvargs ? .cVariadic : .variadic)
                typeFlags.insert(param.isCvargs ? .cVariadic : .variadic)
                if param.isCvargs && isAnyy(type) {
                    type = ty.cvargAny
                }
            }
            params.append(type)
        }

        var returnTypes: [Type] = []
        for returnType in fn.results {
            let operand = check(expr: returnType)
            dependencies.formUnion(operand.dependencies)

            let type = lowerFromMetatype(operand.type, atNode: returnType)
            returnTypes.append(type)
        }

        let returnType = ty.Tuple.make(returnTypes)

        if returnTypes.count == 1 && isVoid(returnTypes[0]) && fn.isDiscardable {
            reportError("#discardable on void returning function is superflous", at: fn.start)
        }

        var type: Type
        type = ty.Function(node: nil, labels: fn.labels, params: params, returnType: returnType, flags: typeFlags)
        type = ty.Metatype(instanceType: type)
        fn.type = type
        return Operand(mode: .type, expr: fn, type: type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(field: StructField) -> Operand {
        let operand = check(expr: field.explicitType)

        let type = lowerFromMetatype(operand.type, atNode: field.explicitType)
        field.type = type
        return Operand(mode: .computed, expr: nil, type: type, constant: nil, dependencies: operand.dependencies)
    }

    @discardableResult
    mutating func check(struct s: StructType) -> Operand {
        var dependencies: Set<Entity> = []

        var width = 0
        var index = 0
        var fields: [ty.Struct.Field] = []
        for x in s.fields {
            let operand = check(field: x)
            dependencies.formUnion(operand.dependencies)

            for name in x.names {
                let field = ty.Struct.Field(ident: name, type: operand.type, index: index, offset: width)
                fields.append(field)

                if let named = x.type as? ty.Named, named.base == nil {
                    reportError("Invalid recursive type \(named)", at: name.start)
                    continue
                }
                // FIXME: This will align fields to bytes, maybe not best default?
                width = (width + x.type.width!).round(upToNearest: 8)
                index += 1
            }
        }
        var type: Type
        type = ty.Struct(width: width, node: s, fields: fields, isPolymorphic: false)
        type = ty.Metatype(instanceType: type)
        s.type = type
        return Operand(mode: .type, expr: s, type: type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(polyStruct: PolyStructType) -> Operand {
        var dependencies: Set<Entity> = []

        var width = 0
        var index = 0
        var fields: [ty.Struct.Field] = []

        for x in polyStruct.polyTypes.list {
            check(polyType: x)
        }

        for x in polyStruct.fields {
            let operand = check(field: x)
            dependencies.formUnion(operand.dependencies)

            for name in x.names {
                let field = ty.Struct.Field(ident: name, type: operand.type, index: index, offset: width)
                fields.append(field)

                if let named = x.type as? ty.Named, named.base == nil {
                    reportError("Invalid recursive type \(named)", at: name.start)
                    continue
                }
                // FIXME: This will align fields to bytes, maybe not best default?
                width = (width + x.type.width!).round(upToNearest: 8)
                index += 1
            }
        }
        var type: Type
        type = ty.Struct(width: width, node: polyStruct, fields: fields, isPolymorphic: true)
        type = ty.Metatype(instanceType: type)
        polyStruct.type = type
        return Operand(mode: .type, expr: polyStruct, type: type, constant: nil, dependencies: dependencies)
    }

    mutating func check(union u: UnionType) -> Operand {
        var dependencies: Set<Entity> = []

        var largestWidth = 0
        var cases: [ty.Union.Case] = []
        for x in u.fields {
            let operand = check(field: x)
            dependencies.formUnion(operand.dependencies)

            for name in x.names {
                let casé = ty.Union.Case(ident: name, type: operand.type)
                cases.append(casé)
                let width = operand.type.width!.round(upToNearest: 8)
                if width > largestWidth {
                    largestWidth = width
                }
            }
        }

        var type: Type
        type = ty.Union(width: largestWidth, cases: cases)
        type = ty.Metatype(instanceType: type)
        u.type = type
        return Operand(mode: .type, expr: u, type: type, constant: nil, dependencies: dependencies)
    }

    mutating func check(variant v: VariantType) -> Operand {
        var dependencies: Set<Entity> = []

        var index = 0
        var largestWidth = 0
        var cases: [ty.Variant.Case] = []
        for x in v.fields {
            let operand = check(field: x)
            dependencies.formUnion(operand.dependencies)

            for name in x.names {
                let casé = ty.Variant.Case(ident: name, type: operand.type, index: index)
                cases.append(casé)
                let width = operand.type.width!.round(upToNearest: 8)
                if width > largestWidth {
                    largestWidth = width
                }

                index += 1
            }
        }

        var type: Type
        type = ty.Variant(width: largestWidth, cases: cases)
        type = ty.Metatype(instanceType: type)
        v.type = type
        return Operand(mode: .type, expr: v, type: type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(enumType e: EnumType) -> Operand {
        var dependencies: Set<Entity> = []

        var explicitType: Type?
        var useExplicitTypeWidth = false
        if let expr = e.explicitType {
            let operand = check(expr: expr)
            dependencies.formUnion(operand.dependencies)

            explicitType = lowerFromMetatype(operand.type, atNode: expr)
            useExplicitTypeWidth = explicitType.map(baseType) is ty.Integer?
        }

        var number: Int = 0
        var biggest: Int = 0

        var cases: [ty.Enum.Case] = []
        for x in e.cases {
            var constant: Value?
            if let value = x.value {
                let operand = check(expr: value, desiredType: explicitType)
                dependencies.formUnion(operand.dependencies)

                constant = operand.constant

                if let explicitType = explicitType {
                    if !convert(operand.type, to: explicitType, at: value) {
                        reportError("Cannot convert value \(operand) to expected type \(explicitType)", at: value.start)
                    } else {
                        if let constant = operand.constant as? UInt64 {
                            if numericCast(constant) > biggest {
                                biggest = numericCast(constant)
                            }
                            number = numericCast(constant)
                        } else if operand.constant == nil {
                            reportError("Enum values must be constant", at: value.start)
                        }
                    }
                } else {
                    if let constant = operand.constant as? UInt64 {
                        if numericCast(constant) > biggest {
                            biggest = numericCast(constant)
                        }
                    } else {
                        reportError("Enum values must be constant Integer", at: value.start)
                        file.attachNote("You may explicitly opt for a different associated type by using enum(string) for example")
                    }
                }
            }
            let c = ty.Enum.Case(ident: x.name, value: x.value, constant: constant, number: number)
            cases.append(c)
            number += 1
            if number > biggest {
                biggest = number
            }
        }

        let width = useExplicitTypeWidth ? explicitType!.width! : biggest.bitsNeeded()
        var type: Type
        type = ty.Enum(width: width, associatedType: explicitType, cases: cases)
        type = ty.Metatype(instanceType: type)
        e.type = type
        return Operand(mode: .type, expr: e, type: type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(unary: Unary, desiredType: Type?) -> Operand {
        let operand = check(expr: unary.element, desiredType: desiredType)
        var type = operand.type!
        var mode = Operand.Mode.computed

        // in case we early exit
        unary.type = ty.invalid

        var constant: Value?
        switch unary.op {
        case .sub:
            constant = operand.constant.map(negate)
            fallthrough

        case .add:
            guard isInteger(type) || isFloatingPoint(type) else {
                reportError("Invalid operation '\(unary.op)' on \(operand)", at: unary.start)
                return Operand.invalid
            }

        case .not:
            guard isBoolean(type) else {
                reportError("Invalid operation '\(unary.op)' on \(operand)", at: unary.start)
                return Operand.invalid
            }
            constant = operand.constant.map(not)

        case .lss:
            guard let pointer = baseType(type) as? ty.Pointer else {
                reportError("Invalid operation '\(unary.op)' on \(operand)", at: unary.start)
                return Operand.invalid
            }
            type = pointer.pointeeType
            mode = .addressable
        case .and:
            guard operand.mode == .addressable else {
                reportError("Cannot take the address of a non lvalue", at: unary.start)
                return Operand.invalid
            }
            type = ty.Pointer(pointeeType: type)

        default:
            reportError("Invalid operation '\(unary.op)' on \(operand)", at: unary.start)
            return Operand.invalid
        }

        unary.type = type
        return Operand(mode: mode, expr: unary, type: type, constant: constant, dependencies: operand.dependencies)
    }


    // FIXME: Refactor this, for the love of all that is good.
    @discardableResult
    mutating func check(binary: Binary, desiredType: Type?) -> Operand {
        var dependencies: Set<Entity> = []

        let lhs = check(expr: binary.lhs)
        let rhs = check(expr: binary.rhs)

        dependencies.formUnion(lhs.dependencies)
        dependencies.formUnion(rhs.dependencies)

        var lhsType = baseType(lhs.type!)
        var rhsType = baseType(rhs.type!)

        // in case we early exit
        binary.type = ty.invalid

        if isInvalid(lhsType) || isInvalid(rhsType) {
            return Operand.invalid
        }

        let resultType: Type
        let op: OpCode.Binary

        binary.isPointerArithmetic = false

        // Handle constraining untyped's etc..
        if isUntypedNumber(lhsType) && rhsType != lhsType {

            guard constrainUntyped(lhsType, to: rhsType) else {
                reportError("Invalid operation '\(binary.op)' between untyped '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
                return Operand.invalid
            }
            if isNil(lhsType) {
                (binary.lhs as! Nil).type = rhsType
            } else if let lhs = binary.lhs as? BasicLit {
                lhs.type = rhsType
            } else if let lhs = binary.lhs as? Convertable {
                lhs.conversion = (lhsType, rhsType)
            } else {
                preconditionFailure("Only convertables should get here")
            }
            lhsType = rhsType
        } else if isUntyped(rhsType) && rhsType != lhsType {

            guard constrainUntyped(rhsType, to: lhsType) else {
                reportError("Invalid operation '\(binary.op)' between '\(lhsType)' and untyped '\(rhsType)'", at: binary.opPos)
                return Operand.invalid
            }

            if isNil(rhsType) {
                (binary.rhs as! Nil).type = lhsType
            } else if let rhs = binary.rhs as? BasicLit {
                rhs.type = lhsType
            } else if let rhs = binary.rhs as? Convertable {
                rhs.conversion = (rhsType, lhsType)
            } else {
                preconditionFailure("Only convertables should get here")
            }
            rhsType = lhsType
        }

        // TODO: REFACTOR
        // TODO: REFACTOR
        // TODO: REFACTOR
        // TODO: REFACTOR
        // TODO: REFACTOR
        // TODO: REFACTOR
        // TODO: REFACTOR

        // Handle extending or truncating
        if lhsType == rhsType && isUntypedInteger(lhsType) {
            lhsType = ty.Integer(width: ty.untypedInteger.width, isSigned: false)
            rhsType = ty.Integer(width: ty.untypedInteger.width, isSigned: false)
            resultType = ty.untypedInteger
        } else if lhsType == rhsType && isUntypedFloatingPoint(lhsType) {
            lhsType = ty.f64
            rhsType = ty.f64
            resultType = ty.untypedFloat
        } else if lhsType == rhsType && !isPointer(lhsType) && !isPointer(rhsType) {
            resultType = lhsType
        } else if isInteger(lhsType), isFloatingPoint(rhsType) {
            resultType = rhsType
        } else if isInteger(rhsType), isFloatingPoint(lhsType) {
            resultType = lhsType
        } else if isFloatingPoint(lhsType) && isFloatingPoint(rhsType) {
            // select the largest
            if lhsType.width! < rhsType.width! {
                resultType = rhsType
            } else {
                resultType = lhsType
            }
        } else if let lhsType = baseType(lhsType) as? ty.Integer, let rhsType = baseType(rhsType) as? ty.Integer {
            guard lhsType.isSigned == rhsType.isSigned else {
                reportError("Implicit conversion between signed and unsigned integers in operator is disallowed", at: binary.opPos)
                return Operand.invalid
            }
            // select the largest
            if lhsType.width! < rhsType.width! {
                resultType = rhsType
            } else {
                resultType = lhsType
            }
        } else if let lhsType = baseType(lhsType) as? ty.Pointer, isInteger(rhsType) {
            // Can only increment/decrement a pointer
            guard binary.op == .add || binary.op == .sub else {
                reportError("Invalid operation '\(binary.op)' between types '\(lhsType) and \(rhsType)'", at: binary.opPos)
                return Operand.invalid
            }

            resultType = lhsType
            binary.isPointerArithmetic = true
        } else if let lhsType = baseType(lhsType) as? ty.Pointer, let rhsType = baseType(rhsType) as? ty.Pointer {
            switch binary.op {
            // allowed for ptr <op> ptr
            case .leq, .lss, .geq, .gtr, .eql, .neq:
                resultType = ty.bool
                binary.isPointerArithmetic = true

            default:
                reportError("Invalid operation '\(binary.op)' between types '\(lhsType) and \(rhsType)'", at: binary.opPos)
                return Operand.invalid
            }
        } else {
            reportError("Invalid operation '\(binary.op)' between types '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
            return Operand.invalid
        }

        let underlyingLhs = (baseType(lhsType) as? ty.Vector)?.elementType ?? lhsType
        let isIntegerOp = isInteger(underlyingLhs) || isPointer(underlyingLhs)

        var type = resultType
        switch binary.op {
        case .lss, .leq, .gtr, .geq:
            guard (isNumber(lhsType) || isVector(lhsType)) && (isNumber(rhsType) || isVector(rhsType)) || binary.isPointerArithmetic else {
                reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
                return Operand.invalid
            }
            op = isIntegerOp ? .icmp : .fcmp
            type = ty.bool
            if let vec = lhsType as? ty.Vector {
                type = ty.Vector(size: vec.size, elementType: type)
            }
        case .eql, .neq:
            guard (isNumber(lhsType) || isBoolean(lhsType) || isVector(lhsType)) && (isNumber(rhsType) || isBoolean(rhsType) || isVector(rhsType)) || binary.isPointerArithmetic else {
                reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
                return Operand.invalid
            }
            op = (isIntegerOp || isBoolean(lhsType) || isBoolean(rhsType)) ? .icmp : .fcmp
            type = ty.bool
            if let vec = lhsType as? ty.Vector {
                type = ty.Vector(size: vec.size, elementType: type)
            }
        case .xor:
            op = .xor
        case .and, .land:
            op = .and
        case .or, .lor:
            op = .or
        case .shl:
            op = .shl
        case .shr:
            op = .lshr // TODO: Arithmatic?
        case .add:
            op = isIntegerOp ? .add : .fadd
        case .sub:
            op = isIntegerOp ? .sub : .fsub
        case .mul:
            op = isIntegerOp ? .mul : .fmul
        case .quo:
            op = isIntegerOp ? .udiv : .fdiv
        case .rem:
            op = isIntegerOp ? .urem : .frem
        default:
            fatalError("Unhandled operator \(binary.op)")
        }

        binary.type = type
        binary.irOp = op
        return Operand(mode: .computed, expr: binary, type: type, constant: apply(lhs.constant, rhs.constant, op: binary.op), dependencies: dependencies)
    }

    @discardableResult
    mutating func check(ternary: Ternary, desiredType: Type?) -> Operand {
        var dependencies: Set<Entity> = []

        let condOperand = check(expr: ternary.cond, desiredType: ty.bool)
        dependencies.formUnion(condOperand.dependencies)

        guard isBoolean(condOperand.type) || isPointer(condOperand.type) || isNumber(condOperand.type) else {
            reportError("Expected a conditional value", at: ternary.cond.start)
            ternary.type = ty.invalid
            return Operand.invalid
        }
        var thenOperand: Operand?
        if let then = ternary.then {
            thenOperand = check(expr: then, desiredType: desiredType)
            dependencies.formUnion(thenOperand!.dependencies)
        }

        let elseOperand = check(expr: ternary.els, desiredType: thenOperand?.type)
        dependencies.formUnion(elseOperand.dependencies)
        
        if let thenType = thenOperand?.type, !convert(elseOperand.type, to: thenType, at: ternary.els) {
            reportError("Expected matching types", at: ternary.start)
        }
        ternary.type = elseOperand.type
        var constant: Value?
        if let cond = condOperand.constant as? UInt64 {
            constant = cond != 0 ? (thenOperand?.constant ?? cond) : elseOperand.constant
        }
        return Operand(mode: .computed, expr: ternary, type: ternary.type, constant: constant, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(selector: Selector, desiredType: Type? = nil) -> Operand {
        var dependencies: Set<Entity> = []

        let operand = check(expr: selector.rec)
        dependencies.formUnion(operand.dependencies)

        let (underlyingType, levelsOfIndirection) = lowerPointer(operand.type)
        selector.levelsOfIndirection = levelsOfIndirection
        switch baseType(underlyingType) {
        case let file as ty.File:
            guard let member = file.memberScope.lookup(selector.sel.name) else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                selector.type = ty.invalid
                return Operand.invalid
            }

            dependencies.insert(member)

            selector.checked = .file(member)
            if member.isConstant {
                selector.constant = member.constant
            }
            selector.sel.entity = member
            if let desiredType = desiredType, isUntypedNumber(member.type!) {
                if constrainUntyped(member.type!, to: desiredType) {
                    selector.conversion = (member.type!, desiredType)
                    selector.type = desiredType
                    // TODO: Check for safe constant conversion
                    return Operand(mode: .addressable, expr: selector, type: desiredType, constant: member.constant, dependencies: dependencies)
                }
            }
            selector.type = member.type
            return Operand(mode: .addressable, expr: selector, type: member.type, constant: member.constant, dependencies: dependencies)

        case let strućt as ty.Struct:
            guard let field = strućt.fields[selector.sel.name] else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                selector.type = ty.invalid
                return Operand.invalid
            }
            selector.checked = .struct(field)
            selector.type = field.type
            return Operand(mode: .addressable, expr: selector, type: field.type, constant: nil, dependencies: dependencies)

        case let array as ty.Array:
            switch selector.sel.name {
            case "len":
                selector.checked = .staticLength(array.length)
                selector.type = ty.u64
            default:
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                selector.type = ty.invalid
                return Operand.invalid
            }
            return Operand(mode: .addressable, expr: selector, type: selector.type, constant: nil, dependencies: dependencies)

        case let slice as ty.Slice:
            switch selector.sel.name {
            case "raw":
                selector.checked = .array(.raw)
                selector.type = ty.Pointer(pointeeType: slice.elementType)
            case "len":
                selector.checked = .array(.length)
                selector.type = ty.u64
            case "cap":
                selector.checked = .array(.capacity)
                selector.type = ty.u64
            default:
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                selector.type = ty.invalid
            }
            return Operand(mode: .addressable, expr: selector, type: selector.type, constant: nil, dependencies: dependencies)

        case let vector as ty.Vector:
            var indices: [Int] = []
            let name = selector.sel.name

            for char in name.characters {
                switch char {
                case "x", "r":
                    indices.append(0)
                case "y" where vector.size >= 2, "g" where vector.size >= 2:
                    indices.append(1)
                case "z" where vector.size >= 3, "b" where vector.size >= 3:
                    indices.append(2)
                case "w" where vector.size >= 4, "a" where vector.size >= 4:
                    indices.append(3)
                default:
                    reportError("'\(name)' is not a component of '\(selector.rec)'", at: selector.sel.start)
                    selector.checked = .invalid
                    selector.type = ty.invalid
                    return Operand(mode: .addressable, expr: selector, type: selector.type, constant: nil, dependencies: dependencies)
                }
            }

            if indices.count == 1 {
                selector.checked = .scalar(indices[0])
                selector.type = vector.elementType
            } else {
                selector.checked = .swizzle(indices)
                selector.type = ty.Vector(size: indices.count, elementType: vector.elementType)
            }

            return Operand(mode: .assignable, expr: selector, type: selector.type, constant: nil, dependencies: dependencies)

        case is ty.KaiString:
            switch selector.sel.name {
            case "raw":
                selector.checked = .array(.raw)
                selector.type = ty.Pointer(pointeeType: ty.u8)
            case "len":
                selector.checked = .array(.length)
                selector.type = ty.u64
            case "cap":
                selector.checked = .array(.capacity)
                selector.type = ty.u64
            default:
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                selector.type = ty.invalid
            }
            return Operand(mode: .addressable, expr: selector, type: selector.type, constant: nil, dependencies: dependencies)

        case let union as ty.Union:
            guard let casé = union.cases[selector.sel.name] else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                selector.type = ty.invalid
                return Operand.invalid
            }
            selector.checked = .union(casé)
            selector.type = casé.type
            return Operand(mode: .addressable, expr: selector, type: casé.type, constant: nil, dependencies: dependencies)

        case let meta as ty.Metatype:
            switch baseType(meta.instanceType) {
            case let e as ty.Enum:
                guard let c = e.cases[selector.sel.name] else {
                    reportError("Case '\(selector.sel)' not found on enum \(operand)", at: selector.sel.start)
                    selector.type = ty.invalid
                    return Operand.invalid
                }
                selector.checked = .enum(c)
                selector.type = e
                return Operand(mode: .computed, expr: selector, type: e, constant: nil, dependencies: dependencies)

            case is ty.Struct:
                fatalError() // TODO

            default:
                break
            }
            fallthrough

        default:
            // Don't spam diagnostics if the type is already invalid
            if !(operand.type is ty.Invalid) {
                reportError("\(operand), does not have a member scope", at: selector.start)
            }

            selector.checked = .invalid
            selector.type = ty.invalid
            return Operand.invalid
        }
    }

    @discardableResult
    mutating func check(subscript sub: Subscript) -> Operand {
        var dependencies: Set<Entity> = []

        let receiver = check(expr: sub.rec)
        let index = check(expr: sub.index, desiredType: ty.i64)

        dependencies.formUnion(receiver.dependencies)
        dependencies.formUnion(index.dependencies)

        guard receiver.mode != .invalid && index.mode != .invalid else {
            sub.type = ty.invalid
            return Operand.invalid
        }

        if !isInteger(index.type) {
            reportError("Cannot subscript with non-integer type '\(index.type!)'", at: sub.index.start)
        }

        let type: Type
        switch baseType(lowerSpecializedPolymorphics(receiver.type)) {
        case let array as ty.Array:
            sub.type = array.elementType
            type = array.elementType

            // TODO: support compile time constants. Compile time constant support
            // will allows us to guard against negative indices as well
            if let lit = sub.index as? BasicLit, let value = lit.constant as? UInt64 {
                if value >= array.length {
                    reportError("Index \(value) is past the end of the array (\(array.length) elements)", at: sub.index.start)
                }
            }

        case let slice as ty.Slice:
            sub.type = slice.elementType
            type = slice.elementType

        case let pointer as ty.Pointer:
            sub.type = pointer.pointeeType
            type = pointer.pointeeType

        case is ty.KaiString:
            sub.type = ty.u8
            type = ty.u8

        default:
            if !(receiver.type is ty.Invalid) {
                reportError("Unable to subscript \(receiver)", at: sub.start)
            }
            return Operand.invalid
        }

        return Operand(mode: .addressable, expr: sub, type: type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(slice: Slice) -> Operand {
        var dependencies: Set<Entity> = []

        let receiver = check(expr: slice.rec)
        let lo = slice.lo.map { check(expr: $0, desiredType: ty.i64) }
        let hi = slice.hi.map { check(expr: $0, desiredType: ty.i64) }

        dependencies.formUnion(receiver.dependencies)
        if let lo = lo {
            dependencies.formUnion(lo.dependencies)
            if  !isInteger(lo.type) {
                reportError("Cannot subscript with non-integer type", at: slice.lo!.start)
            }
        }
        if let hi = hi {
            dependencies.formUnion(hi.dependencies)
            if !isInteger(hi.type) {
                reportError("Cannot subscript with non-integer type", at: slice.lo!.start)
            }
        }

        switch baseType(receiver.type) {
        case let x as ty.Array:
            slice.type = ty.Slice(elementType: x.elementType)
            // TODO: Check for invalid hi & lo's when constant

        case let x as ty.Slice:
            slice.type = x
            // TODO: Check for invalid hi & lo's when constant

        case is ty.KaiString:
            slice.type = ty.Slice(elementType: ty.u8)
            // TODO: Check for invalid hi & lo's when constant

        default:
            if receiver.mode != .invalid {
                reportError("Unable to slice \(receiver)", at: slice.start)
            }
            slice.type = ty.invalid
            return Operand.invalid
        }

        return Operand(mode: .addressable, expr: slice, type: slice.type, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(call: Call) -> Operand {
        var dependencies: Set<Entity> = []

        let callee = check(expr: call.fun)
        dependencies.formUnion(callee.dependencies)

        if callee.type is ty.Metatype {
            let lowered = callee.type.lower()
            if let strućt = lowered as? ty.Struct, strućt.isPolymorphic {
                return check(polymorphicCall: call, calleeType: strućt)
            }
            fatalError("TODO")
        }
        call.checked = .call

        var calleeType = callee.type!
        if let pointer = calleeType as? ty.Pointer, isFunction(pointer.pointeeType) {
            calleeType = pointer.pointeeType
        }

        guard let calleeFn = calleeType as? ty.Function else {
            reportError("Cannot call non-funtion value '\(callee)'", at: call.start)
            call.type = ty.Tuple.make([ty.invalid])
            call.checked = .call
            return Operand.invalid
        }

        if call.args.count > calleeFn.params.count {
            let excessArgs = call.args[calleeFn.params.count...]
            guard calleeFn.isVariadic else {
                reportError("Too many arguments in call to \(call.fun)", at: excessArgs.first!.start)
                call.type = calleeFn.returnType
                return Operand(mode: .computed, expr: call, type: ty.invalid, constant: nil, dependencies: dependencies)
            }

            let expectedType = calleeFn.params.last!
            for arg in excessArgs {
                let argument = check(expr: arg, desiredType: expectedType)
                dependencies.formUnion(argument.dependencies)

                guard convert(argument.type, to: expectedType, at: arg) else {
                    reportError("Cannot convert value '\(argument)' to expected argument type '\(expectedType)'", at: arg.start)
                    file.attachNote("In call to '\(callee)'")
                    continue
                }
            }
        }

        if call.args.count < calleeFn.params.count {
            guard calleeFn.isVariadic, call.args.count + 1 == calleeFn.params.count else {
                reportError("Not enough arguments in call to '\(callee)'", at: call.start)
                return Operand(mode: .computed, expr: call, type: ty.invalid, constant: nil, dependencies: dependencies)
            }
        }

        if isPolymorphic(calleeFn) {
            return check(polymorphicCall: call, calleeType: calleeType as! ty.Function)
        }

        var builtin: BuiltinFunction?
        if calleeFn.isBuiltin, let b = lookupBuiltinFunction(call.fun) {
            if let customCheck = b.onCallCheck {

                // FIXME: How to do Dependencies for customChecks for builtin's??
                var returnType = customCheck(&self, call)
                if (returnType as! ty.Tuple).types.count == 1 {
                    returnType = (returnType as! ty.Tuple).types[0]
                }

                call.type = returnType
                call.checked = .builtinCall(b)

                // TODO: Constants
                return Operand(mode: .computed, expr: call, type: returnType, constant: nil, dependencies: dependencies)
            }
            builtin = b
        }

        for (arg, expectedType) in zip(call.args, calleeFn.params) {
            let argument = check(expr: arg, desiredType: expectedType)
            dependencies.formUnion(argument.dependencies)

            guard convert(argument.type, to: expectedType, at: arg) else {
                reportError("Cannot convert value '\(argument)' to expected argument type '\(expectedType)'", at: arg.start)
                file.attachNote("In call to \(callee)")
                continue
            }
        }

        if let labels = calleeFn.labels {
            for (label, parameter) in zip(call.labels, labels) {
                if let label = label, label.name != parameter.name {
                    reportError("Argument label '\(label.name)' does not match expected label: '\(parameter.name)'", at: label.start)
                }
            }
        }

        if let builtin = builtin {
            call.checked = .builtinCall(builtin)
        } else {
            call.checked = .call
        }

        // splat!
        let returnType = calleeFn.returnType.types.count == 1 ? calleeFn.returnType.types[0] : calleeFn.returnType
        call.type = returnType
        return Operand(mode: .computed, expr: call, type: returnType, constant: nil, dependencies: dependencies)
    }

    @discardableResult
    mutating func check(autocast: Autocast, desiredType: Type?) -> Operand {
        guard let desiredType = desiredType else {
            reportError("Unabled to infer type for autocast", at: autocast.keyword)
            autocast.type = ty.invalid
            return Operand.invalid
        }

        let operand = check(expr: autocast.expr, desiredType: desiredType)

        autocast.type = desiredType
        guard canCast(operand.type, to: desiredType) else {
            reportError("Cannot cast between \(operand) and unrelated type '\(desiredType)'", at: autocast.start)
            autocast.type = ty.invalid
            return Operand(mode: .computed, expr: autocast, type: ty.invalid, constant: nil, dependencies: operand.dependencies)
        }

        return Operand(mode: .computed, expr: autocast, type: desiredType, constant: nil, dependencies: operand.dependencies)
    }

    @discardableResult
    mutating func check(cast: Cast) -> Operand {
        var dependencies: Set<Entity> = []

        var operand = check(expr: cast.explicitType)
        dependencies.formUnion(operand.dependencies)

        var targetType = lowerFromMetatype(operand.type, atNode: cast.explicitType)

        if let poly = targetType as? ty.Polymorphic, let val = poly.specialization.val {
            targetType = val
        }

        // pretend it works for all future statements
        cast.type = targetType

        operand = check(expr: cast.expr, desiredType: targetType)
        dependencies.formUnion(operand.dependencies)

        let exprType = operand.type!

        if exprType == targetType {
            reportError("Unnecissary cast \(operand) to same type", at: cast.start)
            return Operand(mode: .computed, expr: cast, type: targetType, constant: nil, dependencies: dependencies)
        }

        switch cast.kind {
        case .cast:
            guard canCast(exprType, to: targetType) else {
                reportError("Cannot cast \(operand) to unrelated type '\(targetType)'", at: cast.start)
                return Operand(mode: .computed, expr: cast, type: targetType, constant: nil, dependencies: dependencies)
            }

        case .bitcast:
            guard exprType.width == targetType.width else {
                reportError("Cannot bitcast \(operand) to type of different size (\(targetType))", at: cast.keyword)
                return Operand(mode: .computed, expr: cast, type: targetType, constant: nil, dependencies: dependencies)
            }

        default:
            fatalError()
        }

        return Operand(mode: .computed, expr: cast, type: targetType, constant: nil, dependencies: dependencies)
    }

    mutating func check(locationDirective l: LocationDirective, desiredType: Type? = nil) -> Operand {
        switch l.kind {
        case .file:
            l.type = ty.string
            l.constant = file.pathFirstImportedAs
        case .line:
            l.type = (desiredType as? ty.Integer) ?? ty.untypedInteger
            l.constant = UInt64(file.position(for: l.directive).line)
        case .location:
            // TODO: We need to support complex constants first.
            fatalError()
        case .function:
            guard context.expectedReturnType != nil else {
                reportError("#function cannot be used outside of a function", at: l.start)
                l.type = ty.invalid
                return Operand.invalid
            }
            l.type = ty.string
            l.constant = context.nearestFunction?.name ?? "<anonymous fn>"
        default:
            preconditionFailure()
        }

        return Operand(mode: .computed, expr: l, type: l.type, constant: l.constant, dependencies: [])
    }

    mutating func check(polymorphicCall call: Call, calleeType: ty.Function) -> Operand {
        let fnLitNode = calleeType.node!

        // In the parameter scope we want to set T.specialization.val to the argument type.

        guard case .polymorphic(let declaringScope, var specializations)? = fnLitNode.checked else {
            preconditionFailure()
        }

        // Find the polymorphic parameters and determine their types using the arguments provided

        var specializationTypes: [Type] = []
        for (arg, param) in zip(call.args, fnLitNode.params)
            where param.isPolyParameter // FIXME: We don't want the polymorphic type we want the polymorphic Node
        {
            guard !(arg is Nil) else {
                reportError("'nil' requires a contextual type", at: arg.start)
                return Operand.invalid
            }

            let argument = check(expr: arg)
            let type = constrainUntypedToDefault(argument.type!)

            guard specialize(polyType: param.type!, with: type) else {
                reportError("Failed to specialize parameter \(param.name) (type \(param.type!)) with \(argument)", at: arg.start)
                return Operand.invalid
            }

            specializationTypes.append(type)
        }

        // Determine if the types used match any existing specializations
        if let specialization = specializations.first(matching: specializationTypes) {

            // check the remaining arguments
            for (arg, expectedType) in zip(call.args, specialization.strippedType.params)
                where arg.type == nil
            {
                let argument = check(expr: arg, desiredType: expectedType)

                guard convert(argument.type, to: expectedType, at: arg) else {
                    reportError("Cannot convert \(argument) to expected type '\(expectedType)'", at: arg.start)
                    continue
                }
            }

            var returnType = specialization.strippedType.returnType.types.count == 1 ?
                specialization.strippedType.returnType.types[0] : specialization.strippedType.returnType
            returnType = lowerSpecializedPolymorphics(returnType)

            call.type = returnType
            call.checked = .specializedCall(specialization)
            return Operand(mode: .computed, expr: call, type: call.type, constant: nil, dependencies: [])
        }

        // generate a copy of the original FnLit to specialize with.
        let generated = copy(fnLitNode)
        generated.flags.insert(.specialization)

        // There must be 1 param for a function to be polymorphic.
        let originalFile = fnLitNode.params.first!.file!

        // create the specialization it's own scope
        let functionScope = Scope(parent: declaringScope)

        // Change to the scope of the generated function
        let callingScope = context.scope
        let prevNode = context.specializationCallNode
        context.scope = functionScope
        context.specializationCallNode = call

        var params: [Entity] = []

        // Declare polymorphic types for all polymorphic parameters
        for (arg, var param) in zip(call.args, generated.params) {
            // create a unique entity for every parameter
            param = copy(param)
            if param.isPolyParameter {
                // Firstly find the polymorphic type and it's specialization
                let type = findPolymorphic(param.type!)!

                // Create a unique entity for each specialization of each polymorphic type
                let entity = copy(type.entity)

                // Lower any polymorphic types within
                entity.type = lowerSpecializedPolymorphics(entity.type!)

                declare(entity)

            } else {
                assert(arg.type == nil)
                let paramType = lowerSpecializedPolymorphics(param.type!)

                // Go back to the calling scope for checking

                context.scope = callingScope

                let argument = check(expr: arg, desiredType: paramType)

                context.scope = functionScope

                guard convert(argument.type, to: param.type!, at: arg) else {
                    reportError("Cannot convert \(argument) to expected type '\(paramType)'", at: arg.start)
                    return Operand.invalid // We want to early exit if we encounter issues.
                }
            }

            // declare the parameter for and check if there is any previous declaration of T
            declare(param)

            params.append(param)

            param.type = arg.type
            assert(!isPolymorphic(param.type!))
        }

        // TODO: How do we handle invalid types
        let type = check(funcType: generated.explicitType).type.lower() as! ty.Function

        let specialization = FunctionSpecialization(file: originalFile, specializedTypes: specializationTypes, strippedType: type, generatedFunctionNode: generated, mangledName: nil, llvm: nil)
        specializations.append(specialization)
        fnLitNode.checked = .polymorphic(declaringScope: declaringScope, specializations: specializations)

        generated.params = params

        assert(functionScope.members.count > generated.explicitType.params.count, "There had to be at least 1 polymorphic type declared")

        _ = check(funcLit: generated)

        context.scope = callingScope
        context.specializationCallNode = prevNode

        /// Remove specializations from the result type for the callee to check with
        var calleeType = calleeType
        calleeType.returnType.types = calleeType.returnType.types.map(lowerSpecializedPolymorphics)

        var returnType = calleeType.returnType.types.count == 1 ? calleeType.returnType.types[0] : calleeType.returnType
        returnType = lowerSpecializedPolymorphics(returnType)

        call.type = returnType
        call.checked = .specializedCall(specialization)

        return Operand(mode: .computed, expr: call, type: returnType, constant: nil, dependencies: [])
    }

    mutating func check(polymorphicCall call: Call, calleeType: ty.Struct) -> Operand {
        fatalError("TODO")
    }
}

extension Checker {

    // TODO: Version that takes an operand for better error message
    func lowerFromMetatype(_ type: Type, atNode node: Node, function: StaticString = #function, line: UInt = #line) -> Type {

        if let type = type as? ty.Metatype {
            return type.instanceType
        }

        reportError("'\(type)' cannot be used as a type", at: node.start, function: function, line: line)
        return ty.invalid
    }

    func lowerPointer(_ type: Type, levelsOfIndirection: Int = 0) -> (Type, levelsOfIndirection: Int) {
        switch type {
        case let type as ty.Pointer:
            return lowerPointer(type.pointeeType, levelsOfIndirection: levelsOfIndirection + 1)

        default:
            return (type, levelsOfIndirection)
        }
    }

    func newEntity(ident: Ident, type: Type? = nil, flags: Entity.Flag = .none, memberScope: Scope? = nil, owningScope: Scope? = nil, constant: Value? = nil) -> Entity {
        return Entity(ident: ident, type: type, flags: flags, constant: constant, file: file, memberScope: memberScope, owningScope: owningScope, callconv: nil, linkname: nil, mangledName: nil, value: nil)
    }
}

extension Checker {

    func reportError(_ message: String, at pos: Pos, function: StaticString = #function, line: UInt = #line) {
        file.addError(message, pos)
        if let currentSpecializationCall = context.specializationCallNode {
            // FIXME: This produces correct locations but the error added to the file above may be attached to the wrong file.
            file.attachNote("Called from: " + file.position(for: currentSpecializationCall.start).description)
        }
        #if DEBUG
            file.attachNote("In \(file.stage), \(function), line \(line)")
            file.attachNote("At an offset of \(file.offset(pos: pos)) in the file")
        #endif
    }
}

extension Node {
    var isPolymorphic: Bool {
        switch self {
        case let array as ArrayType:
            return array.explicitType.isPolymorphic
        case let darray as SliceType:
            return darray.explicitType.isPolymorphic
        case let pointer as PointerType:
            return pointer.explicitType.isPolymorphic
        case let vector as VectorType:
            return vector.explicitType.isPolymorphic
        case let fnType as FuncType:
            return fnType.params.reduce(false, { $0 || $1.isPolymorphic })
        case is PolyType, is PolyStructType, is PolyParameterList:
            return true
        default:
            return false
        }
    }
}

extension Array where Element == FunctionSpecialization {

    func first(matching specializationTypes: [Type]) -> FunctionSpecialization? {

        outer: for specialization in self {

            for (theirs, ours) in zip(specialization.specializedTypes, specializationTypes) {
                if theirs != ours {
                    continue outer
                }
            }
            return specialization
        }
        return nil
    }
}

func canSequence(_ type: Type) -> Bool {
    switch type {
    case is ty.Array, is ty.Slice, is ty.KaiString:
        return true
    default:
        return false
    }
}

func canVector(_ type: Type) -> Bool {
    switch type {
    case let named as ty.Named:
        return canVector(named.base)
    case is ty.Integer, is ty.FloatingPoint, is ty.Polymorphic:
        return true
    default:
        return false
    }
}

func collectBranches(_ stmt: Stmt) -> [Stmt] {
    switch stmt {
    case is Return:
        return [stmt]
    case let b as Block:
        var branches: [Stmt] = []
        for s in b.stmts {
            branches.append(contentsOf: collectBranches(s))
        }
        return branches

    case let i as If:
        var branches = collectBranches(i.body)
        if let e = i.els {
            branches.append(contentsOf: collectBranches(e))
        }
        return branches

    default:
        return []
    }
}

func allBranchesRet(_ stmts: [Stmt]) -> Bool {
    var hasReturn = false
    var allChildrenRet: Bool?

    for stmt in stmts {
        var allRet = false

        switch stmt {
        case is Return:
            hasReturn = true
        case let iff as If:
            var children = [iff.body]
            if let e = iff.els {
                children.append(e)
            }

            if allBranchesRet(children) {
                allRet = true
            }
        case let block as Block:
            allRet = allBranchesRet(block.stmts)
        case let switc as Switch:
            allRet = allBranchesRet(switc.cases)
        case let cas as CaseClause:
            allRet = allBranchesRet([cas.block])
        case let f as For:
            allRet = allBranchesRet(f.body.stmts)
        case let f as ForIn:
            allRet = allBranchesRet(f.body.stmts)
        default:
            continue
        }

        if let a = allChildrenRet {
            allChildrenRet = a && allRet
        } else {
            allChildrenRet = allRet
        }
    }

    return hasReturn || (allChildrenRet ?? false)
}

let identChars  = Array("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".unicodeScalars)
let digits      = Array("1234567890".unicodeScalars)
func pathToEntityName(_ path: String) -> String? {
    assert(!path.isEmpty)

    func isValidIdentifier(_ str: String) -> Bool {

        if !identChars.contains(str.unicodeScalars.first!) {
            return false
        }

        return str.unicodeScalars.dropFirst()
            .contains(where: { identChars.contains($0) || digits.contains($0) })
    }

    let filename = String(path
        .split(separator: "/").last!
        .split(separator: ".").first!)

    guard isValidIdentifier(filename) else {
        return nil
    }

    return filename
}

func resolveLibraryPath(_ name: String, for currentFilePath: String) -> String? {

    if name.hasSuffix(".framework") {
        // FIXME(vdka): We need to support non system frameworks
        return name
    }

    if let fullpath = absolutePath(for: name) {
        return fullpath
    }

    if let fullpath = absolutePath(for: name, relativeTo: currentFilePath) {
        return fullpath
    }

    // If the library does not exist at a relative path, check system library locations
    if let fullpath = absolutePath(for: name, relativeTo: "/usr/local/lib") {
        return fullpath
    }

    return nil
}
