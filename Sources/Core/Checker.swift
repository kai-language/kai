import LLVM

// sourcery:noinit
struct Checker {
    var file: SourceFile

    var context: Context

    init(file: SourceFile) {
        self.file = file

        let currentScope = Scope(parent: Scope.global, file: file)
        context = Context(scope: currentScope, previous: nil)
    }

    // sourcery:noinit
    class Context {

        var scope: Scope
        var previous: Context?

        var expectedReturnType: Type? = nil
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
            reportError("Previous declaration here: \(previous.ident.start)", at: entity.ident.start)
        }
    }
}

extension Checker {

    mutating func check() {
        for node in file.nodes {
            check(node: node)
        }
    }

    mutating func check(node: Node) {

        switch node {
        case is Empty:
            return

        case is Expr, is ExprStmt:
            return
//            let type = check(expr: expr)
//            if !(type is ty.Invalid || node.isDiscardable || type is ty.Void) {
//                reportError("Expression of type '\(type)' is unused", at: node)
//            }
        case let decl as Declaration:
            check(decl: decl)
        default:
            return
        }
    }

    mutating func check(decl: Declaration) {
        var expectedType: Type?
        var entities: [Entity] = []
        defer {
            for entity in entities {
                declare(entity)
            }
        }

        if let explicitType = decl.explicitType {
            expectedType = check(expr: explicitType)

            if !(decl.isConstant && canConvert(expectedType!, to: ty.type)) {
                expectedType = lowerFromMetatype(expectedType!, atNode: explicitType)
            }
        }
    }

    mutating func check(i: Import) {

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
            
        }
    }
}


// MARK: Expressions

extension Checker {

    mutating func check(expr: Expr, desiredType: Type? = nil) -> Type {

        exit: switch expr {
        case let ident as Ident:
            check(ident: ident)
            break exit

        case let lit as BasicLit:
            check(basicLit: lit, desiredType: desiredType)
            break exit

        case let lit as CompositeLit:
            check(compositeLit: lit)
            break exit

        case let fn as FuncLit:
            check(funcLit: fn)
            break exit

        case let fn as FuncType:
            check(funcType: fn)
            break exit

        case let variadic as VariadicType:
            variadic.type = check(expr: variadic.explicitType)
            break exit

        case let pointer as PointerType:
            var pointee = check(expr: pointer.explicitType)
            pointee = lowerFromMetatype(pointee, atNode: pointer.explicitType)
            let type = ty.Pointer(pointeeType: pointee)
            pointer.type = ty.Metatype(instanceType: type)
            break exit

        case let strućt as StructType:
            check(struct: strućt)
            break exit

        case let paren as Paren:
            paren.type = check(expr: paren.element, desiredType: desiredType)
            break exit

        case let unary as Unary:
            check(unary: unary, desiredType: desiredType)
            break exit

        case let binary as Binary:
            check(binary: binary, desiredType: desiredType)
            break exit

        case let ternary as Ternary:
            check(ternary: ternary, desiredType: desiredType)
            break exit

        case let call as Call:
            check(callOrCast: call)
            break exit

        case let selector as Selector:
            check(selector: selector)
            break exit

        default:
            break exit
        }

        // TODO: Untyped types
        // NOTE: The pattern of `break exit` ensures that types are set on the Expr when we exit.
        return expr.type
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
            lit.value = lit.text
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

                    el.type = check(expr: el.value, desiredType: field.type)
                    guard canConvert(el.type, to: field.type) || implicitlyConvert(el.type, to: field.type) else {
                        reportError("Cannot convert type '\(el.type)' to expected type '\(field.type)'", at: el.value.start)
                        continue
                    }
                } else {
                    el.type = check(expr: el.value, desiredType: field.type)
                    guard canConvert(el.type, to: field.type) || implicitlyConvert(el.type, to: field.type) else {
                        reportError("Cannot convert type '\(el.type)' to expected type '\(field.type)'", at: el.value.start)
                        continue
                    }
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

    @discardableResult
    mutating func check(funcLit fn: FuncLit) -> Type {
        if !fn.isSpecialization {
            pushContext()
        }

        var typeFlags: ty.Function.Flags = .none
        var needsSpecialization = false
        var params: [Type] = []
        for param in fn.params.list {
            needsSpecialization = needsSpecialization || (param.explicitType is PolyType) || param.names.map({ $0.poly }).reduce(false, { $0 || $1 })

            if let variadic = param.type as? VariadicType {
                fn.flags.insert(variadic.isCvargs ? .cVariadic : .variadic)
                typeFlags.insert(variadic.isCvargs ? .cVariadic : .variadic)
            }

            check(node: param)

            params.append(param.type)
        }

        var returnTypes: [Type] = []
        for resultType in fn.results.types {
            var type = check(expr: resultType)
            type = lowerFromMetatype(type, atNode: resultType)
            returnTypes.append(type)
        }

        let returnType = ty.Tuple.make(returnTypes)


        // TODO: Only allow single void return
        if (returnType is ty.Void) && fn.isDiscardable {
            reportError("#discardable on void returning function is superflous", at: fn.start)
        }

        context.expectedReturnType = returnType
        if !needsSpecialization {
            check(node: fn.body)
        }
        context.expectedReturnType = nil

        if needsSpecialization {
            typeFlags.insert(.polymorphic)
        }

        if !fn.isSpecialization {
            popContext()
        }
        fn.type = ty.Function(width: nil, node: fn, params: params, returnType: returnType, flags: typeFlags)
        return fn.type
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

        var type: Type = ty.Function(width: nil, node: nil, params: params, returnType: returnType, flags: typeFlags)
        type = ty.Pointer(pointeeType: type)
        fn.type = ty.Metatype(instanceType: type)
        return type
    }

    @discardableResult
    mutating func check(struct strućt: StructType) -> Type {
        var width = 0
        var index = 0
        var fields: [ty.Struct.Field] = []
        for x in strućt.fields {
            check(node: x) // TODO: Custom check?

            for name in x.names {

                let field = ty.Struct.Field(ident: name, type: x.type, index: index, offset: width)
                fields.append(field)

                // FIXME: This will align fields to bytes, maybe not best default?
                width = (width + (x.type.width ?? 0)).round(upToNearest: 8)
                index += 1
            }
        }
        var type: Type = ty.Struct(width: width, node: strućt, fields: fields, ir: Ref(nil))
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

        case .address:
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

        // Used to communicate any implicit casts to perform for this operation
        var (lCast, rCast): (OpCode.Cast?, OpCode.Cast?) = (nil, nil)

        // Handle extending or truncating
        if lhsType == rhsType {
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
        } else {
            reportError("Invalid operation '\(binary.op)' between types '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
            binary.type = ty.invalid
            return ty.invalid
        }

        assert((lhsType == rhsType) || lCast != nil || rCast != nil, "We must have 2 same types or a way to acheive them by here")

        let isIntegerOp = lhsType is ty.Integer || rhsType is ty.Integer

        var type = resultType
        switch binary.op {
        case .lss, .leq, .gtr, .geq:
            guard (lhsType is ty.Integer || lhsType is ty.FloatingPoint) && (rhsType is ty.Integer || rhsType is ty.FloatingPoint) else {
                reportError("Cannot compare '\(lhsType)' and '\(rhsType)'", at: binary.opPos)
                binary.type = ty.invalid
                return ty.invalid
            }
            op = isIntegerOp ? .icmp : .fcmp
            type = ty.bool

        case .eql, .neq:
            guard (lhsType is ty.Integer || lhsType is ty.FloatingPoint || lhsType is ty.Boolean) && (rhsType is ty.Integer || rhsType is ty.FloatingPoint || rhsType is ty.Boolean) else {
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
    mutating func check(callOrCast call: Call) -> Type {
        var calleeType = check(expr: call.fun)
        if calleeType is ty.Metatype {
            return check(cast: call, to: calleeType.lower())
        }

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
            fatalError("TODO: Polymorphism")
//            return checkPolymorphicCall(callNode: node, calleeType: calleeType)
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
        if (returnType as! ty.Tuple).types.count == 1 {
            returnType = (returnType as! ty.Tuple).types[0]
        }

        call.type = returnType
        if let builtin = builtin {
            call.checked = .builtinCall(builtin)
        } else {
            call.checked = .call
        }

        return returnType
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

    @discardableResult
    mutating func check(selector: Selector) -> Type {
        let aggregateType = check(expr: selector.rec)

        switch aggregateType {
        case let file as ty.File:
            guard let member = file.memberScope.lookup(selector.sel.name) else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                return ty.invalid
            }
            selector.checked = .file(member)
            return member.type!

        case let strućt as ty.Struct:
            guard let field = strućt.fields.first(where: { $0.name == selector.sel.name }) else {
                reportError("Member '\(selector.sel)' not found in scope of '\(selector.rec)'", at: selector.sel.start)
                selector.checked = .invalid
                return ty.invalid
            }
            selector.checked = .struct(field)
            return field.type

        default:
            reportError("Type '\(aggregateType)', does not have a member scope", at: selector.start)
            selector.checked = .invalid
            return ty.invalid
        }
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
        #if DEBUG
            file.attachNote("In \(file.stage), \(function), line \(line)")
            file.attachNote("At an offset of \(file.offset(pos: pos)) in the file")
        #endif
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
        return !(ident.entity.isFile || ident.entity.isLibrary)
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
