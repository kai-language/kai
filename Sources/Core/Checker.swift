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

    mutating func check(expr: Expr, desiredType: Type? = nil) -> Type {

        switch expr {
        case let ident as Ident:
            guard let entity = context.scope.lookup(ident.name) else {
                reportError("Use of undefined identifier '\(ident)'", at: ident.start)
                return ty.invalid
            }
            ident.entity = entity
            guard !entity.flags.contains(.library) else {
                reportError("Cannot use library as expression", at: ident.start)
                return ty.invalid
            }

            if entity.type! is ty.Function {
                return ty.Pointer(pointeeType: entity.type!)
            }

            return entity.type!

        case let lit as BasicLit:
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
                return ty.i64
            case .float:
                lit.value = Double(lit.text)!
                return ty.f64
            case .string:
                lit.value = lit.text
                return ty.string
            default:
                return ty.invalid
            }

        case let lit as CompositeLit:
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
                fatalError() // TODO
            }

        default:
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
