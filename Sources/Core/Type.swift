import LLVM
import OrderedDictionary

protocol Type: CustomStringConvertible {
    var width: Int? { get }
}

protocol NamableType: Type {
    var entity: Entity? { get set }
}

extension Type {
    // The the type doesn't have a width, then we assume it is nil
    var width: Int? { return nil }
}

extension Type {

    func lower() -> Type {
        if self is ty.Invalid {
            return self
        }
        return (self as! ty.Metatype).instanceType
    }
}

func != (lhs: Type, rhs: Type) -> Bool {
    return !(lhs == rhs)
}

func == (lhs: Type, rhs: Type) -> Bool {

    switch (lhs, rhs) {
    case (is ty.Void, is ty.Void),
         (is ty.Anyy, is ty.Anyy),
         (is ty.CVarArg, is ty.CVarArg),
         (is ty.Boolean, is ty.Boolean),
         (is ty.KaiString, is ty.KaiString),
         (is ty.UntypedInteger, is ty.UntypedInteger),
         (is ty.UntypedFloatingPoint, is ty.UntypedFloatingPoint):
        return true
    case (let lhs as ty.Integer, let rhs as ty.Integer):
        return lhs.isSigned == rhs.isSigned && lhs.width == rhs.width
    case (is ty.FloatingPoint, is ty.FloatingPoint):
        return lhs.width == rhs.width
    case (let lhs as ty.Pointer, let rhs as ty.Pointer):
        return lhs.pointeeType == rhs.pointeeType
    case (let lhs as ty.Array, let rhs as ty.Array):
        return lhs.elementType == rhs.elementType && lhs.length == rhs.length
    case (let lhs as ty.Slice, let rhs as ty.Slice):
        return lhs.elementType == rhs.elementType
    case (let lhs as ty.Vector, let rhs as ty.Vector):
        return lhs.elementType == rhs.elementType && lhs.size == rhs.size
    case (let lhs as ty.Struct, let rhs as ty.Struct):
        return lhs.node.start == rhs.node.start
    case (let lhs as ty.Enum, let rhs as ty.Enum):
        return lhs.cases.orderedValues.first?.ident.start == rhs.cases.orderedValues.first?.ident.start
    case (let lhs as ty.Union, let rhs as ty.Union):
        return lhs.cases.orderedValues.first?.ident.start == rhs.cases.orderedValues.first?.ident.start
    case (let lhs as ty.Function, let rhs as ty.Function):
        return lhs.params == rhs.params && lhs.returnType == rhs.returnType
    case (let lhs as ty.Tuple, let rhs as ty.Tuple):
        return lhs.types == rhs.types
    case (let lhs as ty.Metatype, let rhs as ty.Metatype):
        return lhs.instanceType == rhs.instanceType
    case (let lhs as ty.Polymorphic, let rhs as ty.Polymorphic):
        return lhs.entity.ident.start == rhs.entity.ident.start
    case (let lhs as ty.Polymorphic, _):
        return lhs.specialization.val! == rhs
    case (_, let rhs as ty.Polymorphic):
        return rhs.specialization.val! == lhs
    default:
        return false
    }
}

/// Rescursively searches type for a ty.Polymorphic
func findPolymorphic(_ type: Type) -> ty.Polymorphic? {
    switch type {
    case let type as ty.Array:
        return findPolymorphic(type.elementType)
    case let type as ty.Slice:
        return findPolymorphic(type.elementType)
    case let type as ty.Vector:
        return findPolymorphic(type.elementType)
    case let type as ty.Pointer:
        return findPolymorphic(type.pointeeType)

    case let type as ty.Function:
        // FIXME: This needs to return multiple polymorphics. Since functions can have multiple bits
        return type.params.map(findPolymorphic).first ?? nil

        // TODO: @PolyStruct

    case let type as ty.Polymorphic:
        return type
    default:
        return nil
    }
}

/// Recursively searches polyType for a ty.Polymorphic to pair
///  with a matching argType. If found the ty.Polymorphic has
///  its specialization.val set for future use.
///
///     specialize(polyType: "[]$T", with: []f32)
///
/// In this example T matches to f32
///
/// - Returns: Was specialization possible?
func specialize(polyType: Type, with argType: Type) -> Bool {
    switch (polyType, argType) {
    case (let polyType as ty.Array, let argType as ty.Array):
        return specialize(polyType: polyType.elementType, with: argType.elementType)
    case (let polyType as ty.Slice, let argType as ty.Slice):
        return specialize(polyType: polyType.elementType, with: argType.elementType)
    case (let polyType as ty.Vector, let argType as ty.Vector):
        return specialize(polyType: polyType.elementType, with: argType.elementType)
    case (let polyType as ty.Pointer, let argType as ty.Pointer):
        return specialize(polyType: polyType.pointeeType, with: argType.pointeeType)

    case (let polyType as ty.Polymorphic, _):
        polyType.specialization.val = argType
        return true
    default:
        return false
    }
}

func lowerSpecializedPolymorphics(_ type: Type) -> Type {

    switch type {
    case is ty.Anyy,
         is ty.Boolean,
         is ty.CVarArg,
         is ty.FloatingPoint,
         is ty.Integer,
         is ty.KaiString,
         is ty.Void:
        return type

    case let type as ty.Polymorphic:
        return type.specialization.val!

    case var type as ty.Array:
        let elType = lowerSpecializedPolymorphics(type.elementType)
        type.elementType = elType
        return type

    case var type as ty.Vector:
        let elType = lowerSpecializedPolymorphics(type.elementType)
        type.elementType = elType
        return type

    case var type as ty.Slice:
        let elType = lowerSpecializedPolymorphics(type.elementType)
        type.elementType = elType
        return type

    case var type as ty.Pointer:
        let pType = lowerSpecializedPolymorphics(type.pointeeType)
        type.pointeeType = pType
        return type

    case is ty.Enum,
         is ty.Union,
         is ty.Struct,
         is ty.Variant:
        // TODO: do we permit anonymous polymorphic complex types???
        return type

    case let type as ty.Metatype:
        return ty.Metatype(instanceType: lowerSpecializedPolymorphics(type.instanceType))

    case let type as ty.Function:
        //            assert(type.params.reduce(true, { $0 && isPolymorphic($1) }))
        //            assert(type.returnType.types.reduce(true, { $0 && isPolymorphic($1) }))
        return type

    case let type as ty.Tuple:
        return ty.Tuple(width: type.width, types: type.types.map(lowerSpecializedPolymorphics))

    case is ty.UntypedNil,
         is ty.UntypedInteger,
         is ty.UntypedFloatingPoint:
        return type

    case is ty.Invalid:
        return type

    case is ty.File:
        return type

    default:
        preconditionFailure("New Type?")
    }
}

func constrainUntyped(_ type: Type, to targetType: Type) -> Bool {
    switch (type, targetType) {
    case (is ty.UntypedNil, is ty.Pointer),

         (is ty.UntypedInteger, is ty.Integer),
         (is ty.UntypedInteger, is ty.FloatingPoint),
         (is ty.UntypedInteger, is ty.Pointer),

         (is ty.UntypedFloatingPoint, is ty.Integer),
         (is ty.UntypedFloatingPoint, is ty.FloatingPoint):
        return true
    default:
        return false
    }
}

/// - Returns: No default type available for constraint
func constrainUntypedToDefault(_ type: Type) -> Type {
    switch type {
    case is ty.UntypedNil:
        preconditionFailure("You must check for this prior to calling")

    case is ty.UntypedInteger:
        return ty.i64

    case is ty.UntypedFloatingPoint:
        return ty.f64

    default:
        return type
    }
}

extension Array where Element == Type {
    static func == (lhs: [Type], rhs: [Type]) -> Bool {
        for (l, r) in zip(lhs, rhs) {
            if l != r {
                return false
            }
        }
        return true
    }
}

func convert(_ type: Type, to target: Type, at expr: Expr) -> Bool {
    let type = lowerSpecializedPolymorphics(type)
    let target = lowerSpecializedPolymorphics(target)
    if type == target {
        return true
    }

    if let lit = expr as? BasicLit {
        switch (lit.constant, target) {
        case (let const as UInt64, is ty.FloatingPoint):
            lit.constant = Double(const)
            lit.type = target
            return true

        default:
            return false
        }
    }

    var allowed = false
    switch (type, target) {
    case (is ty.UntypedNil, is ty.Pointer),

         (is ty.UntypedInteger, is ty.Integer),
         (is ty.UntypedInteger, is ty.FloatingPoint),

         (is ty.UntypedFloatingPoint, is ty.FloatingPoint),

         (is ty.Array, is ty.Slice):
        allowed = true

    case (is ty.Pointer, let target as ty.Pointer):
        allowed = target.entity === Entity.rawptr

    case (let exprType as ty.Enum, let targetType):
        if let associatedType = exprType.associatedType {
            allowed = canCast(associatedType, to: targetType)
            break
        }
        allowed = targetType is ty.Integer || targetType is ty.UntypedInteger

    case (_, is ty.Anyy):
        allowed = true

    case (_, is ty.CVarArg):
        return true // return immediately, don't perform conversion

    default:
        allowed = false
    }

    guard let expr = expr as? Convertable else {
        return false
    }

    if allowed {
        expr.conversion = (type, target)
    }
    return allowed
}

func canCast(_ exprType: Type, to targetType: Type) -> Bool {
    switch (exprType, targetType) {
    case (is ty.UntypedNil, is ty.Pointer),
         
         (is ty.UntypedInteger, is ty.Integer),
         (is ty.UntypedInteger, is ty.FloatingPoint),
         (is ty.UntypedInteger, is ty.Pointer),
         
         (is ty.UntypedFloatingPoint, is ty.Integer),
         (is ty.UntypedFloatingPoint, is ty.FloatingPoint),
         
         (is ty.Integer, is ty.Integer),
         (is ty.Integer, is ty.FloatingPoint),
         (is ty.Integer, is ty.Pointer),
         
         (is ty.FloatingPoint, is ty.FloatingPoint),
         (is ty.FloatingPoint, is ty.Integer),
         
         (is ty.Pointer, is ty.Boolean),
         (is ty.Pointer, is ty.Integer),
         (is ty.Pointer, is ty.Pointer),
         (is ty.Pointer, is ty.Function),

         (is ty.Function, is ty.Pointer),
         
         (is ty.Array, is ty.Slice):
        return true

    case (is ty.Function, is ty.Function):
        return true // TODO: Only if bitcasting.

    case (let exprType as ty.Enum, let targetType):
        if let associatedType = exprType.associatedType {
            return canCast(associatedType, to: targetType)
        }
        return targetType is ty.Integer || targetType is ty.UntypedInteger

    default:
        return false
    }
}

/// A name space containing all type specifics
enum ty {

    // TODO: Use platform pointer types where appropriate

    struct Void: Type {
        var width: Int? { return 0 }
    }

    struct Boolean: Type, NamableType {
        weak var entity: Entity?
        var width: Int? { return 1 }
    }

    struct Integer: Type, NamableType {
        weak var entity: Entity?
        var width: Int?
        var isSigned: Bool
    }

    struct FloatingPoint: Type, NamableType {
        weak var entity: Entity?
        var width: Int?
    }

    struct KaiString: Type, NamableType {
        weak var entity: Entity?
        var width: Int? { return 3 * platformPointerWidth } // pointer, length, capacity
    }

    struct Pointer: Type, NamableType {
        weak var entity: Entity?
        var width: Int? { return platformPointerWidth }
        var pointeeType: Type

        init(pointeeType: Type) {
            self.pointeeType = pointeeType
        }
    }

    struct Array: Type, NamableType {
        weak var entity: Entity?
        var width: Int? { return elementType.width! * length }
        var length: Int!
        var elementType: Type

        init(length: Int!, elementType: Type) {
            self.length = length
            self.elementType = elementType
        }
    }

    struct Slice: Type, NamableType {
        weak var entity: Entity?
        var width: Int? { return 3 * platformPointerWidth } // pointer, length, capacity
        var elementType: Type

        init(elementType: Type) {
            self.elementType = elementType
        }
    }

    struct Vector: Type, NamableType {
        weak var entity: Entity?
        var width: Int? { return elementType.width! * size }
        var size: Int
        var elementType: Type

        init(size: Int, elementType: Type) {
            self.size = size
            self.elementType = elementType
        }
    }

    struct Anyy: Type {
        var width: Int? { return platformPointerWidth }
    }

    struct Struct: Type, NamableType {
        weak var entity: Entity?
        var width: Int?

        var node: Node
        var fields: OrderedDictionary<String, Field>

        var isPolymorphic: Bool

        init(width: Int, node: Node, fields: [Field], isPolymorphic: Bool = false) {
            self.width = width
            self.node = node
            self.fields = [:]
            for field in fields {
                self.fields[field.ident.name] = field
            }
            self.isPolymorphic = isPolymorphic
        }

        struct Field {
            let ident: Ident
            let type: Type

            var index: Int
            var offset: Int

            var name: Swift.String {
                return ident.name
            }
        }

        @available(*, unavailable)
        static func make(named name: String, builder: IRBuilder, _ members: [(String, Type)]) -> BuiltinType {
            // NOTE: Not sure how to do these yet. Likely this will be gone.
            fatalError()
            /*
            var width = 0
            var fields: [Struct.Field] = []
            for (index, (name, type)) in members.enumerated() {

                let ident = Ident(start: noPos, name: name, entity: nil, type: nil, cast: nil, constant: nil)

                let field = Struct.Field(ident: ident, type: type, index: index, offset: width)
                fields.append(field)

                width = (width + type.width!).round(upToNearest: 8)
            }

            let irType = builder.createStruct(name: name)
            var irTypes: [IRType] = []
            for field in fields {
                let fieldType = canonicalize(field.type)
                irTypes.append(fieldType)
            }

            let entity = Entity.makeBuiltin(name)

            irType.setBody(irTypes)

            var type: Type
            type = Struct(width: width, node: Empty(semicolon: noPos, isImplicit: true), fields: fields, isPolymorphic: false)
            type = Metatype(instanceType: type)

            entity.type = type
            return BuiltinType(entity: entity, type: type)
            */
        }
    }

    struct Union: Type, NamableType {
        weak var entity: Entity?
        var width: Int?
        var cases: OrderedDictionary<String, Case>

        init(width: Int, cases: [Case]) {
            self.width = width
            self.cases = [:]
            for c in cases {
                self.cases[c.ident.name] = c
            }
        }

        struct Case {
            var ident: Ident
            var type: Type
        }
    }

    struct Variant: Type, NamableType {
        weak var entity: Entity?
        var width: Int?
        var cases: OrderedDictionary<String, Case>

        init(width: Int, cases: [Case]) {
            self.width = width
            self.cases = [:]
            for c in cases {
                self.cases[c.ident.name] = c
            }
        }

        struct Case {
            var ident: Ident
            var type: Type
            var index: Int
        }
    }

    struct Enum: Type, NamableType {
        weak var entity: Entity?
        var width: Int?
        var associatedType: Type?
        var cases: OrderedDictionary<String, Case>

        init(width: Int, associatedType: Type?, cases: [Case]) {
            self.width = width
            self.associatedType = associatedType
            self.cases = [:]
            for c in cases {
                self.cases[c.ident.name] = c
            }
        }

        struct Case {
            var ident: Ident
            let value: Expr?
            let constant: Value?
            let number: Int
        }
    }

    struct Function: Type, NamableType {
        weak var entity: Entity?
        var node: FuncLit?
        var labels: [Ident]?
        var params: [Type]
        var returnType: Tuple
        var flags: Flags

        struct Flags: OptionSet {
            var rawValue: UInt8

            static let none         = Flags(rawValue: 0b0000)
            static let variadic     = Flags(rawValue: 0b0001)
            static let cVariadic    = Flags(rawValue: 0b0011)
            static let polymorphic  = Flags(rawValue: 0b0100)
            static let builtin      = Flags(rawValue: 0b1000)
        }

        static func make(_ params: [Type], _ returnType: [Type], _ flags: Flags = .builtin) -> Function {
            return Function(entity: nil, node: nil, labels: nil, params: params, returnType: ty.Tuple.init(width: nil, types: returnType), flags: flags)
        }
    }

    struct UntypedNil: Type {
        var width: Int? { return MemoryLayout<Int>.size }
    }

    struct UntypedInteger: Type, CustomStringConvertible {
        var width: Int? { return 64 } // NOTE: Bump up to larger size for more precision.
    }

    struct UntypedFloatingPoint: Type {
        var width: Int? { return 64 }
    }

    struct Metatype: Type {

        var instanceType: Type

        init(instanceType: Type) {
            self.instanceType = instanceType
        }
    }

    struct Polymorphic: Type {
        unowned var entity: Entity
        var specialization: Ref<Type?>
    }

    /// - Note: Only used in Function
    struct Tuple: Type {
        var width: Int?
        var types: [Type]

        static func make(_ types: [Type]) -> Tuple {

            let width = types.map({ $0.width ?? 0 }).reduce(0, +)

            return Tuple(width: width, types: types)
        }
    }

    struct Invalid: Type {
        static let instance = Invalid()
    }

    struct CVarArg: Type {
        static let instance = CVarArg()
    }

    struct File: Type {
        let memberScope: Scope

        init(memberScope: Scope) {
            self.memberScope = memberScope
        }
    }
}

func isUntyped(_ type: Type) -> Bool {
    return type is ty.UntypedNil || isUntypedNumber(type)
}

func isUntypedNumber(_ type: Type) -> Bool {
    return type is ty.UntypedInteger || type is ty.UntypedFloatingPoint
}

func isNumber(_ type: Type) -> Bool {
    return isUntypedNumber(type) || isInteger(type) || isFloatingPoint(type)
}

func isVoid(_ type: Type) -> Bool {
    return type is ty.Void
}

func isBoolean(_ type: Type) -> Bool {
    return type is ty.Boolean
}

func isInteger(_ type: Type) -> Bool {
    return type is ty.Integer || type is ty.UntypedInteger
}

func isFloatingPoint(_ type: Type) -> Bool {
    return type is ty.FloatingPoint || type is ty.UntypedFloatingPoint
}

func isKaiString(_ type: Type) -> Bool {
    return type is ty.KaiString
}

func isPointer(_ type: Type) -> Bool {
    return type is ty.Pointer
}

func isArray(_ type: Type) -> Bool {
    return type is ty.Array
}

func isSlice(_ type: Type) -> Bool {
    return type is ty.Slice
}

func isVector(_ type: Type) -> Bool {
    return type is ty.Vector
}

func isAnyy(_ type: Type) -> Bool {
    return type is ty.Anyy
}

func isStruct(_ type: Type) -> Bool {
    return type is ty.Struct
}

func isUnion(_ type: Type) -> Bool {
    return type is ty.Union
}

func isVariant(_ type: Type) -> Bool {
    return type is ty.Variant
}

func isEnum(_ type: Type) -> Bool {
    return type is ty.Enum
}

func isFunction(_ type: Type) -> Bool {
    return type is ty.Function
}

func isNil(_ type: Type) -> Bool {
    return type is ty.UntypedNil
}

func isUntypedInteger(_ type: Type) -> Bool {
    return type is ty.UntypedInteger
}

func isUntypedFloatingPoint(_ type: Type) -> Bool {
    return type is ty.UntypedFloatingPoint
}

func isMetatype(_ type: Type) -> Bool {
    return type is ty.Metatype
}

func isPolymorphic(_ type: Type) -> Bool {
    return findPolymorphic(type) != nil
}

func isTuple(_ type: Type) -> Bool {
    return type is ty.Tuple
}

func isInvalid(_ type: Type) -> Bool {
    return type is ty.Invalid
}

func isCVarArg(_ type: Type) -> Bool {
    return type is ty.CVarArg
}

func isFile(_ type: Type) -> Bool {
    return type is ty.File
}
