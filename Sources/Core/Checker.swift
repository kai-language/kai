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

        var expectedReturnType: ty.Tuple? = nil
        var specializationCallNode: Call? = nil

        var nextCase: CaseClause?
        var switchLabel: Entity?
        var nearestSwitchLabel: Entity? {
            return switchLabel ?? previous?.nearestSwitchLabel
        }
        var inSwitch: Bool {
            return nearestSwitchLabel != nil
        }

        var loopLabel: Entity?
        var nearestLoopLabel: Entity? {
            return loopLabel ?? previous?.nearestLoopLabel
        }
        var inLoop: Bool {
            return nearestLoopLabel != nil
        }

        var nearestLabel: Entity? {
            assert(loopLabel == nil || switchLabel == nil)
            return loopLabel ?? switchLabel ?? previous?.nearestLabel
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

        if let previous = previous {

            reportError("Invalid redeclaration of '\(previous.name)'", at: entity.ident.start)
            file.attachNote("Previous declaration here: \(previous.ident.start)")
        }
    }
}

extension Checker {

    mutating func check() {
        for node in file.nodes {
            check(topLevelStmt: node)
        }
    }

    mutating func check(topLevelStmt: TopLevelStmt) {
        switch topLevelStmt {
        case let i as Import:
            check(import: i)
        case let l as Library:
            check(library: l)
        case let f as Foreign:
            check(foreign: f)
        case let d as DeclBlock: // #callconv "c" { ... }
            check(anyDecl: d, isForeign: false)
        case let d as Declaration:
            check(decl: d)
        default:
            fatalError()
        }
    }

    mutating func check(stmt: Stmt) {

        switch stmt {
        case is Empty:
            return

        case let stmt as ExprStmt:
            let type = check(expr: stmt.expr)
            switch stmt.expr {
            case let call as Call:
                switch call.checked! {
                case .call, .specializedCall:
                    guard let fnNode = (call.fun.type as? ty.Function)?.node, fnNode.isDiscardable || type is ty.Void else {
                        fallthrough
                    }
                    return
                default:
                    break
                }

            default:
                if !(type is ty.Invalid) {
                    reportError("Expression of type '\(type)' is unused", at: stmt.start)
                }
            }
        case let decl as Declaration:
            check(decl: decl)
        case let d as Decl:
            check(anyDecl: d, isForeign: false)
        case let assign as Assign:
            check(assign: assign)
        case let block as Block:
            for stmt in block.stmts {
                check(stmt: stmt)
            }
        case let ret as Return:
            let expectedReturn = context.expectedReturnType!

            var isVoidReturn = false
            if expectedReturn.types.count == 1 && expectedReturn.types[0] is ty.Void {
                isVoidReturn = true
            }

            for (value, expected) in zip(ret.results, expectedReturn.types) {
                let type = check(expr: value, desiredType: expected)
                if type != expected {
                    if isVoidReturn {
                        reportError("Void function should not return a value", at: value.start)
                        return
                    } else {
                        reportError("Cannot convert type '\(type)' to expected type '\(expected)'", at: value.start)
                    }
                }
            }

            if ret.results.count < expectedReturn.types.count, !(expectedReturn.types.first is ty.Void) {
                reportError("Not enough arguments to return", at: ret.start)
                return
            }

            if ret.results.count > expectedReturn.types.count {
                reportError("Too many arguments to return", at: ret.start)
                return
            }

        case let fór as For:
            check(for: fór)

        case let íf as If:
            check(if: íf)

        default:
            print("Warning: statement '\(stmt)' passed through without getting checked")
        }
    }

    mutating func check(decl: Declaration) {
        var expectedType: Type?
        var entities: [Entity] = []

        if let explicitType = decl.explicitType {
            expectedType = check(expr: explicitType)
            expectedType = lowerFromMetatype(expectedType!, atNode: explicitType)
        }

        if decl.values.count == 1 && decl.names.count > 1, let call = decl.values[0] as? Call {
            // Declares more than 1 new entity with the RHS being a call returning multiple values.
            let tuple = check(callOrCast: call) as! ty.Tuple
            let types = tuple.types

            for (ident, type) in zip(decl.names, types) {
                if ident.name == "_" {
                    entities.append(Entity.anonymous)
                    continue
                }
                let entity = Entity(ident: ident, type: type, flags: .none, memberScope: nil, owningScope: nil, value: nil)
                if decl.isConstant {
                    entity.flags.insert(.constant)
                }
                if type is ty.Metatype {
                    entity.flags.insert(.type)
                }
                entities.append(entity)
            }
            decl.entities = entities

        } else if decl.values.isEmpty {
            assert(!decl.isConstant)

            let type = expectedType!
            for ident in decl.names {
                let entity = Entity(ident: ident, type: type, flags: .none, memberScope: nil, owningScope: nil, value: nil)
                if decl.isConstant {
                    entity.flags.insert(.constant)
                }
                if type is ty.Metatype {
                    entity.flags.insert(.type)
                }
                entities.append(entity)
            }

        } else {

            for (ident, value) in zip(decl.names, decl.values) {
                var type = check(expr: value, desiredType: expectedType)
                if ident.name == "_" {
                    entities.append(Entity.anonymous)
                    continue
                }
                if let expectedType = expectedType, type is ty.Function, let pointer = expectedType as? ty.Pointer {
                    if type != pointer.pointeeType {
                        reportError("Cannot convert value of type '\(type)' to specified type '\(expectedType)'", at: value.start)
                        type = expectedType
                    }
                } else if let expectedType = expectedType, type != expectedType {
                    reportError("Cannot convert value of type '\(type)' to specified type '\(expectedType)'", at: value.start)
                    type = expectedType
                }

                let entity = Entity(ident: ident, type: type, flags: .none, memberScope: nil, owningScope: nil, value: nil)
                if decl.isConstant {
                    entity.flags.insert(.constant)
                }
                if type is ty.Metatype {
                    entity.flags.insert(.type)
                }
                entities.append(entity)
            }
        }

        decl.entities = entities
        for entity in entities {
            declare(entity)
        }
    }

    mutating func check(anyDecl: Decl, isForeign: Bool) {

        switch anyDecl {
        case let f as Foreign:
            check(foreign: f)

        case let b as DeclBlock:
            for decl in b.decls {
                check(anyDecl: decl, isForeign: isForeign)
            }

        case let d as Declaration:
            guard isForeign else {
                check(decl: d)
                // I think the only way we can get here is will a callconv block
                //  we therefore should only allow functions
                // TODO: ^
                return
            }

            let ident = d.names[0]
            if ident.name == "_" {
                reportError("The dispose identifer is not a permitted name in foreign declarations", at: ident.start)
                return
            }

            // only 2 forms allowed by the parser `i: ty` or `i :: ty`
            //  these represent a foreign variable and a foreign constant respectively.
            // In both cases these are no values, just an explicitType is set. No values.
            var type = check(expr: d.explicitType!)
            type = lowerFromMetatype(type, atNode: d.explicitType!)
            if d.isConstant {
                if let pointer = type as? ty.Pointer, pointer.pointeeType is ty.Function {
                    type = pointer.pointeeType
                }
            }

            let entity = Entity(ident: ident, type: type, flags: d.isConstant ? [.constant, .foreign] : .foreign, memberScope: nil, owningScope: nil, value: nil)
            declare(entity)
            d.entities = [entity]

        default:
            fatalError()
        }
    }

    mutating func check(assign: Assign) {

        if assign.rhs.count == 1 && assign.lhs.count > 1, let call = assign.rhs[0] as? Call {
            let tuple = check(callOrCast: call) as! ty.Tuple
            let types = tuple.types

            for (lhs, type) in zip(assign.lhs, types) {
                let expectedType = check(expr: lhs)

                if !canConvert(type, to: expectedType) && !implicitlyConvert(type, to: expectedType) {
                    reportError("Cannot assign value of type '\(type)' to type '\(expectedType)'", at: call.start)
                }
            }
        } else {

            for (lhs, rhs) in zip(assign.lhs, assign.rhs) {
                let lhsType = check(expr: lhs)
                let rhsType = check(expr: rhs)

                if !canConvert(rhsType, to: lhsType) && !implicitlyConvert(rhsType, to: lhsType) {
                    reportError("Cannot assign value of type '\(rhsType)' to type \(lhsType)", at: rhs.start)
                }
            }

            if assign.lhs.count != assign.rhs.count {
                reportError("Assignment count missmatch \(assign.lhs.count) = \(assign.rhs.count)", at: assign.start)
            }
        }
    }

    mutating func check(import i: Import) {

        var entity: Entity?
        if let alias = i.alias {
            entity = Entity(ident: alias, type: nil, flags: .file, memberScope: nil, owningScope: nil, value: nil)
        } else if !i.importSymbolsIntoScope {
            guard let name = i.resolvedName else {
                reportError("Cannot infer an import name for '\(i.path)'", at: i.path.start)
                file.attachNote("You will need to manually specify one")
                return
            }
            let ident = Ident(start: noPos, name: name, entity: nil)
            entity = Entity(ident: ident, type: nil, flags: .file, memberScope: nil, owningScope: nil, value: nil)
        }

        // TODO: Ensure the import has been fully checked

        if i.importSymbolsIntoScope {
            for member in i.scope.members {
                guard !member.flags.contains(.file) else {
                    continue
                }

                declare(member, scopeOwnsEntity: false)
            }
        } else if let entity = entity {
            entity.memberScope = i.scope
            entity.type = ty.File(memberScope: i.scope)
            declare(entity)
        }
    }

    mutating func check(library l: Library) {

        guard let lit = l.path as? BasicLit, lit.token == .string else {
            reportError("Library path must be a string literal value", at: l.path.start)
            return
        }

        let path = lit.value as! String

        l.resolvedName = l.alias?.name ?? pathToEntityName(path)

        // TODO: Use the Value system to resolve any string value.
        guard let name = l.resolvedName else {
            reportError("Cannot infer an import name for '\(path)'", at: l.path.start)
            file.attachNote("You will need to manually specify one")
            return
        }
        let ident = l.alias ?? Ident(start: noPos, name: name, entity: nil)
        let entity = Entity(ident: ident, type: nil, flags: .library, memberScope: nil, owningScope: nil, value: nil)
        declare(entity)

        if path != "libc" && path != "llvm" {

            guard let linkpath = resolveLibraryPath(path, for: file.fullpath) else {
                reportError("Failed to resolve path for '\(path)'", at: l.path.start)
                return
            }
            file.package.linkedLibraries.insert(linkpath)
        }
    }

    mutating func check(foreign f: Foreign) {

        // TODO: Check callconv
        guard let entity = context.scope.lookup(f.library.name) else {
            reportError("Use of undefined identifier '\(f.library)'", at: f.library.start)
            return
        }
        guard entity.flags.contains(.library) else {
            reportError("Expected a library", at: f.library.start)
            return
        }
        f.library.entity = entity

        check(anyDecl: f.decl, isForeign: true)
    }
}


// MARK: Expressions

extension Checker {

    mutating func check(expr: Expr, desiredType: Type? = nil) -> Type {

        switch expr {
        case let ident as Ident:
            check(ident: ident)

        case let lit as BasicLit:
            check(basicLit: lit, desiredType: desiredType)

        case let lit as CompositeLit:
            check(compositeLit: lit)

        case let fn as FuncLit:
            check(funcLit: fn)

        case let fn as FuncType:
            check(funcType: fn)

        case let polyType as PolyType:
            check(polyType: polyType)

        case let variadic as VariadicType:
            variadic.type = check(expr: variadic.explicitType)

        case let pointer as PointerType:
            var pointee = check(expr: pointer.explicitType)
            pointee = lowerFromMetatype(pointee, atNode: pointer.explicitType)
            let type = ty.Pointer(pointeeType: pointee)
            pointer.type = ty.Metatype(instanceType: type)

        case let array as ArrayType:
            var element = check(expr: array.explicitType)
            element = lowerFromMetatype(element, atNode: array)
            // TODO: extract compile-time constant from expression `array.length`
            _ = check(expr: array.length)
            guard
                let lit = array.length as? BasicLit,
                let length = lit.value as? UInt64
            else {
                reportError("Currently, only array literals are allowed for array length", at: array.length.start)
                return ty.invalid
            }

            let type = ty.Array(length: Int(length), elementType: element)
            array.type = ty.Metatype(instanceType: type)

        case let strućt as StructType:
            check(struct: strućt)

        case let paren as Paren:
            paren.type = check(expr: paren.element, desiredType: desiredType)

        case let unary as Unary:
            check(unary: unary, desiredType: desiredType)

        case let binary as Binary:
            check(binary: binary, desiredType: desiredType)

        case let ternary as Ternary:
            check(ternary: ternary, desiredType: desiredType)

        case let selector as Selector:
            check(selector: selector)

        case let subsćript as Subscript:
            check(subscript: subsćript)

        case let call as Call:
            check(callOrCast: call)

        default:
            print("Warning: expression '\(expr)' passed through without getting checked")
        }

        // TODO: Untyped types
        // NOTE: The pattern of `break exit` ensures that types are set on the Expr when we exit.
        return expr.type ?? ty.invalid
    }

    @discardableResult
    mutating func check(ident: Ident) -> Type {
        guard let entity = context.scope.lookup(ident.name) else {
            reportError("Use of undefined identifier '\(ident)'", at: ident.start)
            ident.entity = Entity.invalid
            return ty.invalid
        }
        ident.entity = entity
        guard !entity.flags.contains(.library) else {
            reportError("Cannot use library as expression", at: ident.start)
            ident.entity = Entity.invalid
            return ty.invalid
        }
        ident.entity = entity
        return entity.type!
    }

    @discardableResult
    mutating func check(basicLit lit: BasicLit, desiredType: Type?) -> Type {
        // TODO: Untyped types
        switch lit.token {
        case .int:
            switch lit.text.prefix(2) {
            case "0x":
                let text = String(lit.text.suffix(1))
                lit.value = UInt64(text, radix: 16)!
            case "0o":
                let text = String(lit.text.suffix(1))
                lit.value = UInt64(text, radix: 8)!
            case "0b":
                let text = String(lit.text.suffix(1))
                lit.value = UInt64(text, radix: 2)!
            default:
                lit.value = UInt64(lit.text, radix: 10)!
            }
            if let desiredType = desiredType, desiredType is ty.Integer || desiredType is ty.FloatingPoint {
                lit.type = desiredType
            } else {
                lit.type = ty.i64
            }
        case .float:
            lit.value = Double(lit.text)!
            lit.type = ty.f64
        case .string:
            // NOTE: unquoted in the Parser.
            lit.type = ty.string
        default:
            lit.type = ty.invalid
        }
        return lit.type
    }

    @discardableResult
    mutating func check(compositeLit lit: CompositeLit) -> Type {
        var type = check(expr: lit.explicitType)
        type = lowerFromMetatype(type, atNode: lit.explicitType)

        switch type {
        case let type as ty.Struct:
            if lit.elements.count > type.fields.count {
                reportError("Too many values in struct initializer", at: lit.elements[type.fields.count].start)
            }
            for (el, field) in zip(lit.elements, type.fields) {

                if let key = el.key {
                    guard let ident = key as? Ident else {
                        reportError("Expected identifier for key in composite literal for struct", at: key.start)
                        lit.type = ty.invalid
                        return ty.invalid
                    }
                    guard let field = type.fields.first(where: { $0.name == ident.name }) else {
                        reportError("Unknown field '\(ident)' for '\(type)'", at: ident.start)
                        continue
                    }

                    el.structField = field
                    el.type = check(expr: el.value, desiredType: field.type)
                    guard canConvert(el.type, to: field.type) || implicitlyConvert(el.type, to: field.type) else {
                        reportError("Cannot convert type '\(el.type)' to expected type '\(field.type)'", at: el.value.start)
                        continue
                    }
                } else {
                    el.structField = field
                    el.type = check(expr: el.value, desiredType: field.type)
                    guard canConvert(el.type, to: field.type) || implicitlyConvert(el.type, to: field.type) else {
                        reportError("Cannot convert type '\(el.type!)' to expected type '\(field.type)'", at: el.value.start)
                        continue
                    }
                }
            }
            lit.type = type
            return type

        case let type as ty.Array:
            if lit.elements.count != type.length {
                reportError("Element count (\(lit.elements.count)) does not match array length (\(type.length))", at: lit.start)
            }

            for el in lit.elements {
                el.type = check(expr: el.value, desiredType: type.elementType)
                guard canConvert(el.type, to: type.elementType) || implicitlyConvert(el.type, to: type.elementType) else {
                    reportError("Cannot convert element of type '\(el.type.description)' to expected type '\(type.elementType)'", at: el.value.start)
                    continue
                }
            }

            lit.type = type
            return type

        default:
            reportError("Invalid type for composite literal", at: lit.start)
            lit.type = ty.invalid
            return ty.invalid
        }
    }

    mutating func check(for fór: For) {
        pushContext()
        defer {
            popContext()
        }

        if let initializer = fór.initializer {
            check(stmt: initializer)
        }

        if let cond = fór.cond {
            let type = check(expr: cond, desiredType: ty.bool)
            if !canConvert(type, to: ty.bool) && !implicitlyConvert(type, to: ty.bool) {
                reportError("Cannot convert '\(type)' to expected type 'bool'", at: cond.start)
            }
        }

        if let step = fór.step {
            check(stmt: step)
        }

        check(stmt: fór.body)
    }

    mutating func check(if iff: If) {
        pushContext()
        defer {
            popContext()
        }

        let condType = check(expr: iff.cond, desiredType: ty.bool)
        if !canConvert(condType, to: ty.bool) && !implicitlyConvert(condType, to: ty.bool) {
            reportError("Cannot convert '\(condType)' to expected type 'bool'", at: iff.cond.start)
        }

        check(stmt: iff.body)
        if let els = iff.els {
            check(stmt: els)
        }
    }

    @discardableResult
    mutating func check(param: Parameter) -> Type {

        var type = check(expr: param.explicitType)
        type = lowerFromMetatype(type, atNode: param.explicitType)
        let entity = Entity(ident: param.name, type: type, flags: param.isExplicitPoly ? .constant : .none, memberScope: nil, owningScope: nil, value: nil)
        if param.isExplicitPoly {
            type = ty.Polymorphic(entity: entity, specialization: Ref(nil))
        }
        declare(entity)
        param.entity = entity
        return type
    }

    @discardableResult
    mutating func check(polyType: PolyType) -> Type {
        if polyType.type != nil {
            // Do not redeclare any poly types which have been checked before.
            return polyType.type
        }
        switch polyType.explicitType {
        case let ident as Ident:
            let entity = Entity(ident: ident, type: ty.invalid, flags: .implicitType, memberScope: nil, owningScope: nil, value: nil)
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
    mutating func check(funcLit fn: FuncLit) -> ty.Function {
        if !fn.isSpecialization {
            pushContext()
        }

        var typeFlags: ty.Function.Flags = .none
        var needsSpecialization = false
        var params: [Type] = []
        for param in fn.params.list {
            if fn.isSpecialization && param.type != nil {
                // The polymorphic parameters type has been set by the callee
                params.append(param.type)
                continue
            }

            needsSpecialization = needsSpecialization || (param.explicitType is PolyType) || param.isExplicitPoly

            var type = check(param: param)

            if let paramType = param.explicitType as? VariadicType {
                fn.flags.insert(paramType.isCvargs ? .cVariadic : .variadic)
                typeFlags.insert(paramType.isCvargs ? .cVariadic : .variadic)
                if paramType.isCvargs && type is ty.Anyy {
                    type = ty.cvargAny
                }
            }

            if let polyType = type as? ty.Polymorphic, fn.isSpecialization && !param.isExplicitPoly {
                type = polyType.specialization.val!
            }

            if fn.isSpecialization {
                assert(!(type is ty.Polymorphic) || param.isExplicitPoly)
            }

            params.append(type)
        }

        var returnTypes: [Type] = []
        for resultType in fn.results.types {
            var type = check(expr: resultType)
            type = lowerFromMetatype(type, atNode: resultType)
            if let polyType = type as? ty.Polymorphic, fn.isSpecialization {
                type = polyType.specialization.val!
            }
            returnTypes.append(type)
        }

        let returnType = ty.Tuple.make(returnTypes)


        // TODO: Only allow single void return
        if (returnType.types[0] is ty.Void) && fn.isDiscardable {
            reportError("#discardable on void returning function is superflous", at: fn.start)
        }

        context.expectedReturnType = returnType
        if !needsSpecialization {
            check(stmt: fn.body)
        }
        context.expectedReturnType = nil

        if needsSpecialization && !fn.isSpecialization {
            typeFlags.insert(.polymorphic)
            fn.type = ty.Function(entity: .anonymous, node: fn, params: params, returnType: returnType, flags: .polymorphic)
            fn.checked = .polymorphic(declaringScope: context.scope, specializations: [])
        } else {
            fn.type = ty.Function(entity: .anonymous, node: fn, params: params, returnType: returnType, flags: typeFlags)
            fn.checked = .regular(context.scope)
        }

        if !fn.isSpecialization {
            popContext()
        }
        return fn.type as! ty.Function
    }

    @discardableResult
    mutating func check(funcType fn: FuncType) -> Type {
        var typeFlags: ty.Function.Flags = .none
        var params: [Type] = []
        for param in fn.params {
            var type = check(expr: param)
            type = lowerFromMetatype(type, atNode: param)

            if let param = param as? VariadicType {
                fn.flags.insert(param.isCvargs ? .cVariadic : .variadic)
                typeFlags.insert(param.isCvargs ? .cVariadic : .variadic)
                if param.isCvargs && type is ty.Anyy {
                    type = ty.cvargAny
                }
            }
            params.append(type)
        }

        var returnTypes: [Type] = []
        for returnType in fn.results {
            var type = check(expr: returnType)
            type = lowerFromMetatype(type, atNode: returnType)
            returnTypes.append(type)
        }

        let returnType = ty.Tuple.make(returnTypes)

        if returnTypes.count == 1 && returnTypes[0] is ty.Void && fn.isDiscardable {
            reportError("#discardable on void returning function is superflous", at: fn.start)
        }

        var type: Type
        type = ty.Function(entity: .anonymous, node: nil, params: params, returnType: returnType, flags: typeFlags)
        type = ty.Pointer(pointeeType: type)
        fn.type = ty.Metatype(instanceType: type)
        return type
    }

    @discardableResult
    mutating func check(field: StructField) -> Type {

        var type = check(expr: field.explicitType)
        type = lowerFromMetatype(type, atNode: field.explicitType)
        field.type = type
        return type
    }

    @discardableResult
    mutating func check(struct strućt: StructType) -> Type {
        var width = 0
        var index = 0
        var fields: [ty.Struct.Field] = []
        for x in strućt.fields {
            let type = check(field: x) // TODO: Custom check?

            for name in x.names {

                let field = ty.Struct.Field(ident: name, type: type, index: index, offset: width)
                fields.append(field)

                // FIXME: This will align fields to bytes, maybe not best default?
                width = (width + (x.type.width ?? 0)).round(upToNearest: 8)
                index += 1
            }
        }
        var type: Type
        type = ty.Struct(entity: .anonymous, width: width, node: strućt, fields: fields, ir: Ref(nil))
        type = ty.Metatype(instanceType: type)
        strućt.type = type
        return type
    }

    @discardableResult
    mutating func check(unary: Unary, desiredType: Type?) -> Type {
        var type = check(expr: unary.element, desiredType: desiredType)

        switch unary.op {
        case .add, .sub:
            guard type is ty.Integer || type is ty.FloatingPoint else {
                reportError("Invalid operation '\(unary.op)' on type '\(type)'", at: unary.start)
                unary.type = ty.invalid
                return ty.invalid
            }

        case .lss:
            guard let pointer = type as? ty.Pointer else {
                reportError("Invalid operation '\(unary.op)' on type '\(type)'", at: unary.start)
                unary.type = ty.invalid
                return ty.invalid
            }
            type = pointer.pointeeType

        case .and:
            guard canLvalue(unary.element) else {
                reportError("Cannot take the address of a non lvalue", at: unary.start)
                unary.type = ty.invalid
                return ty.invalid
            }
            type = ty.Pointer(pointeeType: type)

        case .not:
            guard type is ty.Boolean else {
                reportError("Invalid operation '\(unary.op)' on type '\(type)'", at: unary.start)
                unary.type = ty.invalid
                return ty.invalid
            }

        default:
            reportError("Invalid operation '\(unary.op)' on type '\(type)'", at: unary.start)
            unary.type = ty.invalid
            return ty.invalid
        }

        unary.type = type
        return type
    }

    @discardableResult
    mutating func check(binary: Binary, desiredType: Type?) -> Type {
        let lhsType = check(expr: binary.lhs)
        let rhsType = check(expr: binary.rhs)

        let resultType: Type
        let op: OpCode.Binary

        var isPointerArithmetic = false

        // Used to communicate any implicit casts to perform for this operation
        var (lCast, rCast): (OpCode.Cast?, OpCode.Cast?) = (nil, nil)

        // Handle extending or truncating
        if lhsType == rhsType && !(lhsType is ty.Pointer) && !(rhsType is ty.Pointer){
            resultType = lhsType
        } else if let lhsType = lhsType as? ty.Integer, rhsType is ty.FloatingPoint {
            lCast = lhsType.isSigned ? .siToFP : .uiToFP
            resultType = rhsType
        } else if let rhsType = rhsType as? ty.Integer, lhsType is ty.FloatingPoint {
            rCast = rhsType.isSigned ? .siToFP : .uiToFP
            resultType = lhsType
        } else if lhsType is ty.FloatingPoint && rhsType is ty.FloatingPoint {
            // select the largest
            if lhsType.width! < rhsType.width! {
                resultType = rhsType
                lCast = .fpext
            } else {
                resultType = lhsType
                rCast = .fpext
            }
        } else if let lhsType = lhsType as? ty.Integer, let rhsType = rhsType as? ty.Integer {
            guard lhsType.isSigned == rhsType.isSigned else {
                reportError("Implicit conversion between signed and unsigned integers in operator is disallowed", at: binary.opPos)
                binary.type = ty.invalid
                return ty.invalid
            }
            // select the largest
            if lhsType.width! < rhsType.width! {
                resultType = rhsType
                lCast = lhsType.isSigned ? OpCode.Cast.sext : OpCode.Cast.zext
            } else {
                resultType = lhsType
                rCast = rhsType.isSigned ? OpCode.Cast.sext : OpCode.Cast.zext
            }
        } else if let lhsType = lhsType as? ty.Pointer, rhsType is ty.Integer {
            // Can only increment/decrement a pointer
            guard binary.op == .add || binary.op == .sub else {
                reportError("Invalid operation '\(binary.op)' between types '\(lhsType) and \(rhsType)'", at: binary.opPos)
                binary.type = ty.invalid
                return ty.invalid
            }

            resultType = lhsType
            isPointerArithmetic = true
        } else if let lhsType = lhsType as? ty.Pointer, let rhsType = rhsType as? ty.Pointer {
            switch binary.op {
            // allowed for ptr <op> ptr
            case .leq, .lss, .geq, .gtr, .eql, .neq:
                resultType = ty.bool
                isPointerArithmetic = true

            default:
                reportError("Invalid operation '\(binary.op)' between types '\(lhsType) and \(rhsType)'", at: binary.opPos)
                binary.type = ty.invalid
                return ty.invalid
            }
        } else {
            reportError("Invalid operation '\(binary.op)' between types '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
            binary.type = ty.invalid
            return ty.invalid
        }

        assert((lhsType == rhsType) || lCast != nil || rCast != nil || isPointerArithmetic, "We must have 2 same types or a way to acheive them by here")

        let isIntegerOp = lhsType is ty.Integer || rhsType is ty.Integer || lhsType is ty.Pointer

        var type = resultType
        switch binary.op {
        case .lss, .leq, .gtr, .geq:
            guard (lhsType is ty.Integer || lhsType is ty.FloatingPoint) && (rhsType is ty.Integer || rhsType is ty.FloatingPoint) || isPointerArithmetic else {
                reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
                binary.type = ty.invalid
                return ty.invalid
            }
            op = isIntegerOp ? .icmp : .fcmp
            type = ty.bool

        case .eql, .neq:
            guard (lhsType is ty.Integer || lhsType is ty.FloatingPoint || lhsType is ty.Boolean) && (rhsType is ty.Integer || rhsType is ty.FloatingPoint || rhsType is ty.Boolean) || isPointerArithmetic else {
                reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
                binary.type = ty.invalid
                return ty.invalid
            }
            op = (isIntegerOp || lhsType is ty.Boolean || rhsType is ty.Boolean) ? .icmp : .fcmp
            type = ty.bool
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
        binary.irLCast = lCast
        binary.irRCast = rCast
        binary.isPointerArithmetic = isPointerArithmetic
        return type
    }

    @discardableResult
    mutating func check(ternary: Ternary, desiredType: Type?) -> Type {
        let condType = check(expr: ternary.cond)
        guard condType == ty.bool || condType is ty.Pointer || condType is ty.Integer || condType is ty.FloatingPoint else {
            reportError("Expected a conditional value", at: ternary.cond.start)
            ternary.type = ty.invalid
            return ty.invalid
        }
        var thenType: Type?
        if let then = ternary.then {
            thenType = check(expr: then, desiredType: desiredType)
        }

        let type = check(expr: ternary.els, desiredType: thenType)
        if let thenType = thenType, !canConvert(thenType, to: type) {
            reportError("Expected matching types", at: ternary.start)
        }
        ternary.type = type
        return type
    }

    @discardableResult
    mutating func check(selector: Selector) -> Type {
        let aggregateType = check(expr: selector.rec)

        switch aggregateType {
        case let file as ty.File:
            guard let member = file.memberScope.lookup(selector.sel.name) else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                return ty.invalid
            }
            selector.checked = .file(member)
            return member.type!

        case let strućt as ty.Struct:
            guard let field = strućt.fields.first(where: { $0.name == selector.sel.name }) else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                return ty.invalid
            }
            selector.checked = .struct(field)
            return field.type

        default:
            // Don't spam diagnostics if the type is already invalid
            if !(aggregateType is ty.Invalid) {
                reportError("Type '\(aggregateType)', does not have a member scope", at: selector.start)
            }

            return ty.invalid
        }
    }

    @discardableResult
    mutating func check(subscript sub: Subscript) -> Type {
        let recType = check(expr: sub.rec)
        let indexType = check(expr: sub.index, desiredType: ty.i64)

        if !canConvert(indexType, to: ty.i64) && !implicitlyConvert(indexType, to: ty.i64) {
            reportError("Cannot subscript with non-integer type", at: sub.index.start)
        }

        let type: Type

        switch recType {
        case let array as ty.Array:
            sub.type = array.elementType
            sub.checked = .array
            type = array.elementType

        case let pointer as ty.Pointer:
            sub.type = pointer.pointeeType
            sub.checked = .pointer
            type = pointer.pointeeType

        default:
            if !(recType is ty.Invalid) {
                reportError("Unable to subscript type \(recType)", at: sub.start)
            }

            return ty.invalid
        }


        return type
    }

    @discardableResult
    mutating func check(callOrCast call: Call) -> Type {
        var calleeType = check(expr: call.fun)
        if calleeType is ty.Metatype {
            return check(cast: call, to: calleeType.lower())
        }
        call.checked = .call

        if let pointer = calleeType as? ty.Pointer, pointer.pointeeType is ty.Function {
            calleeType = pointer.pointeeType
        }

        guard let calleeFn = calleeType as? ty.Function else {
            reportError("Cannot call value of non-funtion type '\(calleeType)'", at: call.start)
            call.type = ty.Tuple.make([ty.invalid])
            return call.type
        }

        if call.args.count > calleeFn.params.count {
            let excessArgs = call.args[calleeFn.params.count...]
            guard calleeFn.isVariadic else {
                reportError("Too many arguments in call to \(call.fun)", at: excessArgs.first!.start)
                call.type = calleeFn.returnType
                return calleeFn.returnType
            }

            let expectedType = calleeFn.params.last!
            for arg in excessArgs {
                let argType = check(expr: arg, desiredType: expectedType)

                guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                    reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg.start)
                    continue
                }
            }
        }

        if call.args.count < calleeFn.params.count {
            guard calleeFn.isVariadic, call.args.count + 1 == calleeFn.params.count else {
                reportError("Not enough arguments in call to '\(call.fun)", at: call.start)
                return calleeFn.returnType
            }
        }

        if calleeFn.isPolymorphic {
            return check(polymorphicCall: call, calleeType: calleeType as! ty.Function)
        }

        var builtin: BuiltinFunction?
        if calleeFn.isBuiltin, let b = lookupBuiltinFunction(call.fun) {
            if let customCheck = b.onCallCheck {
                var returnType = customCheck(&self, call)
                if (returnType as! ty.Tuple).types.count == 1 {
                    returnType = (returnType as! ty.Tuple).types[0]
                }

                call.type = returnType
                call.checked = .builtinCall(b)

                return returnType
            }
            builtin = b
        }

        for (arg, expectedType) in zip(call.args, calleeFn.params) {

            let argType = check(expr: arg, desiredType: expectedType)

            guard argType == expectedType || implicitlyConvert(argType, to: expectedType) else {
                reportError("Cannot convert value of type '\(argType)' to expected argument type '\(expectedType)'", at: arg.start)
                continue
            }
        }

        var returnType = calleeFn.returnType

        call.type = returnType
        if let builtin = builtin {
            call.checked = .builtinCall(builtin)
        } else {
            call.checked = .call
        }

        // if there is a single return value then don't wrap it in a tuple
        return returnType.types.count == 1 ? returnType.types[0] : returnType
    }

    mutating func check(cast: Call, to targetType: Type) -> Type {
        guard cast.args.count == 1, let arg = cast.args.first else {
            if cast.args.count == 0 {
                reportError("Missing argument for cast to \(targetType)", at: cast.start)
            } else { // args.count > 1
                reportError("Too many arguments for cast to \(targetType)", at: cast.start)
            }
            cast.type = targetType
            return targetType
        }

        cast.type = targetType

        // FIXME: Because of desired type here, the following check may fire when an implicit check is performed
        let argType = check(expr: arg, desiredType: targetType)
        var op: OpCode.Cast = .bitCast

        if argType == targetType {
            reportError("Unnecissary cast to same type", at: cast.start)
            cast.type = targetType
            return targetType
        }

        if let argType = argType as? ty.Integer, let targetType = targetType as? ty.Integer { // 2 integers
            op = (argType.width! > targetType.width!) ? .trunc : (targetType.isSigned ? .sext : .zext)
        } else if let argType = argType as? ty.FloatingPoint, let targetType = targetType as? ty.FloatingPoint { // 2 floats
            op = (argType.width! > targetType.width!) ? .fpTrunc : .fpext
        } else if let argType = argType as? ty.Integer, targetType is ty.FloatingPoint { // TODO: Cast from int to float of different size
            op = argType.isSigned ? .siToFP : .uiToFP
        } else if argType is ty.FloatingPoint, let targetType = targetType as? ty.Integer { // TODO: Cast from float to int of different size
            op = targetType.isSigned ? .fpToSI : .fpToUI
        } else {
            reportError("Cannot cast between unrelated types '\(argType)' and '\(targetType)'", at: cast.start)
        }
        cast.type = targetType
        cast.checked = .cast(op)
        return targetType
    }

    mutating func check(polymorphicCall call: Call, calleeType: ty.Function) -> Type {
        let fnLitNode = calleeType.node!

        guard case .polymorphic(let declaringScope, var specializations)? = fnLitNode.checked else {
            fatalError()
        }

        var specializationTypes: [Type] = []
        let functionScope = Scope(parent: declaringScope)
        var explicitIndices: [Int] = []
        for (index, (param, arg)) in zip(fnLitNode.params.list, call.args).enumerated()
            where param.isExplicitPoly || param.type is ty.Polymorphic
        {
            let argType = check(expr: arg, desiredType: param.type)
            specializationTypes.append(argType)

            if param.isExplicitPoly, let polyType = param.type as? ty.Polymorphic {

                guard canConvert(argType, to: param.type) || implicitlyConvert(argType, to: param.type) else {
                    reportError("Cannot convert type '\(argType)' to expected type '\(param.type)'", at: arg.start)
                    continue
                }

                explicitIndices.append(index)

                polyType.specialization.val = argType
                _ = functionScope.insert(param.entity)
                // TODO: Should we be ignoring conflicts? Will this miss duplicate param names?
            } else if let polyType = param.type as? ty.Polymorphic {

                polyType.specialization.val = argType
                _ = functionScope.insert(polyType.entity)
                // TODO: Should we be ignoring conflicts? Will this miss duplicate param names?
            }
        }

        var strippedArgs = call.args
        for index in explicitIndices.reversed() {
            strippedArgs.remove(at: index)
        }

        if let specialization = specializations.first(matching: specializationTypes) {
            // use an existing specialization
            for (arg, expectedType) in zip(strippedArgs, specialization.strippedType.params)
                where arg.type == nil
            {
                let argType = check(expr: arg, desiredType: expectedType)

                guard canConvert(argType, to: expectedType) || implicitlyConvert(argType, to: expectedType) else {
                    reportError("Cannot convert type '\(argType)' to expected type '\(expectedType)'", at: arg.start)
                    continue
                }
            }

            call.type = specialization.strippedType.returnType
            call.checked = .specializedCall(specialization)
            return specialization.strippedType.returnType
        }

        // generated a new specialization
        let generated = copy(fnLitNode)
        generated.flags.insert(.specialization)

        var specializationTypesCopy = specializationTypes
        for (param, generatedParam) in zip(fnLitNode.params.list, generated.params.list)
            where param.isExplicitPoly || param.type is ty.Polymorphic
        {
            generatedParam.entity.type = specializationTypesCopy.removeFirst()
        }

        let prevScope = context.scope
        context.scope = functionScope
        context.specializationCallNode = call

        let type = check(funcLit: generated)

        context.scope = prevScope
        context.specializationCallNode = nil

        var typesCopy = specializationTypes
        for (arg, expectedType) in zip(strippedArgs, type.params) {
            var argType: Type
            if arg.type != nil {
                argType = typesCopy.removeFirst()
            } else {
                argType = check(expr: arg, desiredType: expectedType)
            }

            guard canConvert(argType, to: expectedType) || implicitlyConvert(argType, to: expectedType) else {
                reportError("Cannot convert type '\(argType)' to expected type '\(expectedType)'", at: arg.start)
                continue
            }
        }

        let specialization = FunctionSpecialization(specializedTypes: specializationTypes, strippedType: type, generatedFunctionNode: generated, llvm: nil)

        // TODO: Tuple splat?
        call.type = type.returnType
        call.checked = .specializedCall(specialization)

        // update the specializations list on the original FnLit
        specializations.append(specialization)
        fnLitNode.checked = .polymorphic(declaringScope: declaringScope, specializations: specializations)

        // TODO: Tuple splat?
        return type.returnType
    }
}

extension Checker {

    func lowerFromMetatype(_ type: Type, atNode node: Node, function: StaticString = #function, line: UInt = #line) -> Type {

        if let type = type as? ty.Metatype {
            return type.instanceType
        }

        reportError("'\(type)' cannot be used as a type", at: node.start, function: function, line: line)
        return ty.invalid
    }

    /// - Returns: Was a conversion performed
    func implicitlyConvert(_ type: Type, to targetType: Type) -> Bool {

        if targetType is ty.Anyy {
            fatalError("Implement this once we have an any type")
        }

        if targetType is ty.CVarArg {
            // No actual conversion need be done.
            return true
        }

        return false
    }
}

extension Checker {

    func reportError(_ message: String, at pos: Pos, function: StaticString = #function, line: UInt = #line) {
        file.addError(message, pos)
        if let currentSpecializationCall = context.specializationCallNode {
            file.attachNote("Called from: " + file.position(for: currentSpecializationCall.start).description)
        }
        #if DEBUG
            file.attachNote("In \(file.stage), \(function), line \(line)")
            file.attachNote("At an offset of \(file.offset(pos: pos)) in the file")
        #endif
    }
}

extension Parameter {
    var isExplicitPoly: Bool {
        return dollar != nil
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

func canLvalue(_ expr: Expr) -> Bool {

    switch expr {
    case is Unary, is Binary, is Ternary,
         is BasicLit,
         is Call, is FuncLit:
    return false
    case let paren as Paren:
        return canLvalue(paren.element)
    case let ident as Ident:
        if ident.name == "_" {
            return true
        }
        if ident === BuiltinEntity.trué || ident === BuiltinEntity.falsé {
            return false
        }
        return !(ident.entity.isFile || ident.entity.isLibrary)
    case is Subscript:
        return true
    default:
        return false
    }
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
