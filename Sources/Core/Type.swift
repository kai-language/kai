import LLVM
import OrderedDictionary

protocol Type: CustomStringConvertible {
    var width: Int? { get }
}

protocol NamableType: Type {}
protocol IRNamableType: Type {}

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

    func unwrappingVector() -> Type {
        switch self {
        case let type as ty.Vector:
            return type.elementType
        case let type as ty.Named:
            return type.base.unwrappingVector()
        default:
            return self
        }
    }
}

func != (lhs: Type, rhs: Type) -> Bool {
    return !(lhs == rhs)
}

func == (lhs: Type, rhs: Type) -> Bool {

    switch (baseType(lhs), baseType(rhs)) {
    case (is ty.Void, is ty.Void),
         (is ty.Anyy, is ty.Anyy),
         (is ty.UntypedInteger, is ty.UntypedInteger),
         (is ty.UntypedFloat, is ty.UntypedFloat):
        return true
    case (let lhs as ty.Boolean, let rhs as ty.Boolean):
        return lhs.width == rhs.width
    case (let lhs as ty.Integer, let rhs as ty.Integer):
        return lhs.isSigned == rhs.isSigned && lhs.width == rhs.width
    case (is ty.Float, is ty.Float):
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
    case (let lhs as ty.Named, let rhs as ty.Named):
        return lhs.base == rhs.base
    case (let lhs as ty.Named, _):
        return lhs.base == rhs
    case (_, let rhs as ty.Named):
        return lhs == rhs.base
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
        // FIXME: @polyfunctions This needs to return multiple polymorphics. Since functions can have multiple bits
        return type.params.map(findPolymorphic).first ?? nil

        // TODO: @PolyStruct

    case let type as ty.Polymorphic:
        return type
    default:
        return nil
    }
}

/// Unwraps a pointer (or nested pointers) until it finds a concrete type.
func findConcreteType(_ type: Type) -> Type {
    guard let ptr = type as? ty.Pointer else {
        return type
    }

    return findConcreteType(ptr.pointeeType)
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
    // FIXME: @polyfunctions handle functions
    let polyType = baseType(polyType)
    let argType = baseType(argType)

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
         is ty.Float,
         is ty.Integer,
         is ty.Void:
        return type

    case let type as ty.Polymorphic:
        return type.specialization.val!

    case var type as ty.Array:
        type.elementType = lowerSpecializedPolymorphics(type.elementType)
        return type

    case var type as ty.Vector:
        type.elementType = lowerSpecializedPolymorphics(type.elementType)
        return type

    case var type as ty.Slice:
        type.elementType = lowerSpecializedPolymorphics(type.elementType)
        return type

    case var type as ty.Pointer:
        type.pointeeType = lowerSpecializedPolymorphics(type.pointeeType)
        return type

    case is ty.Enum,
         is ty.Union,
         is ty.Struct:
        // TODO: do we permit anonymous polymorphic complex types???
        return type

    case var type as ty.Function:
        type.params = type.params.map(lowerSpecializedPolymorphics)
        // No polymorphic return types.
        return type

    case let type as ty.Named:
        return ty.Named(entity: type.entity, base: lowerSpecializedPolymorphics(type.base) as! NamableType) // NOTE: can we assert?

    case let type as ty.Metatype:
        return ty.Metatype(instanceType: lowerSpecializedPolymorphics(type.instanceType))

    case let type as ty.Tuple:
        return ty.Tuple(width: type.width, types: type.types.map(lowerSpecializedPolymorphics))

    case is ty.UntypedInteger,
         is ty.UntypedFloat:
        return type

    case is ty.Invalid:
        return type

    case is ty.File:
        return type

    default:
        preconditionFailure("New Type?")
    }
}

/// Unwraps a named types
func baseType(_ type: Type) -> Type {
    return (type as? ty.Named)?.base ?? type
}

func constrainUntyped(_ type: Type, to targetType: Type) -> Bool {
    switch (type, targetType) {
    case (is ty.UntypedInteger, is ty.Integer),
         (is ty.UntypedInteger, is ty.Float),
         (is ty.UntypedInteger, is ty.Pointer),

         (is ty.UntypedFloat, is ty.Integer),
         (is ty.UntypedFloat, is ty.Float):
        return true
    default:
        return false
    }
}

/// - Returns: No default type available for constraint
func constrainUntypedToDefault(_ type: Type) -> Type {
    switch type {
    case is ty.UntypedInteger:
        return ty.i64

    case is ty.UntypedFloat:
        return ty.f64

    default:
        return type
    }
}

extension Array where Element == Type {
    static func == (lhs: [Type], rhs: [Type]) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
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

    var allowed = false
    switch (type, target) {
    case (is ty.UntypedInteger, is ty.Integer),
         (is ty.UntypedInteger, is ty.Float),
         (is ty.UntypedFloat, is ty.Float):
        if let lit = expr as? BasicLit {
            lit.type = target
            return true
        }
        allowed = true

    case (_, is ty.UntypedInteger):
        // NOTE: Should we handle this as we do below, allowing string to convert to untyped integer?
        break

    case (_, let target as ty.Integer):
        if isInteger(target), target.width! >= 8, let expr = expr as? BasicLit, let string = expr.constant as? String {
            switch (target.width!, string.utf8.count) {
            case (8, 1):
                expr.type = target
                expr.constant = UInt64(string.utf8.first!)
                return true
            case (16, 1), (16, 2):
                allowed = true
                expr.type = target
                expr.constant = UInt64(string.utf16.first!)
                return true
            case (32, 1), (32, 2), (32, 3), (32, 4):
                allowed = true
                expr.type = target
                expr.constant = UInt64(string.unicodeScalars.first!)
                return true
            default:
                allowed = false
            }
        }

     case (is ty.Array, is ty.Slice):
        // FIXME: @Test I am not sure this should actually convert
        allowed = true

    case (is ty.Pointer, is ty.Pointer):
        // NOTE: Conversion to rawptr is handled earlier
        allowed = false

    case (is ty.Boolean, is ty.Boolean):
        allowed = true

    case (let enumType as ty.Enum, is ty.Integer),
         (is ty.Integer, let enumType as ty.Enum):
        // FIXME: Decide the rules for casting to and from integers
        allowed = canCast(enumType.backingType, to: target)

    case (is ty.Enum, is ty.UntypedInteger),
         (is ty.UntypedInteger, is ty.Enum):
        allowed = true

    case (_, is ty.Anyy):
        allowed = true

    case (let type as ty.Named, let target as ty.Named):
        if target.entity === Entity.rawptr && type.base is ty.Pointer {
            allowed = true
            break
        }
        return convert(type.base, to: target.base, at: expr)

    case (let type as ty.Named, _):
        if let lit = expr as? BasicLit, let string = lit.constant as? String, string.unicodeScalars.count == 1 {
            // TODO: @unicode check the length of the unicode scalar to determine if it would fit in a type, allow conversion up to 32 bit integers
            if target == ty.u8 {
                allowed = true
                break
            }
        }

        return convert(type.base, to: target, at: expr)

    case (_, let target as ty.Named):
        if target.entity === Entity.rawptr && type is ty.Pointer {
            allowed = true
            break
        }
        return convert(type, to: target.base, at: expr)

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
    switch (baseType(exprType), baseType(targetType)) {
    case (is ty.UntypedInteger, is ty.Integer),
         (is ty.UntypedInteger, is ty.Float),
         (is ty.UntypedInteger, is ty.Pointer),

         (is ty.UntypedFloat, is ty.Integer),
         (is ty.UntypedFloat, is ty.Float),

         (is ty.Integer, is ty.Integer),
         (is ty.Integer, is ty.Float),
         (is ty.Integer, is ty.Pointer),

         (is ty.Boolean, is ty.Boolean),
         (is ty.Boolean, is ty.Integer),

         (is ty.Float, is ty.Float),
         (is ty.Float, is ty.Integer),

         (is ty.Pointer, is ty.Integer),
         (is ty.Pointer, is ty.Pointer),
         (is ty.Pointer, is ty.Function),

         (is ty.Function, is ty.Pointer),

         (is ty.Array, is ty.Slice):
        return true

    case (let l as ty.Slice, let r as ty.Slice):
        return l.elementType == r.elementType

    case (is ty.Function, is ty.Function):
        return true // TODO: Only if bitcasting.

    case (let exprType as ty.Enum, let targetType):
        // FIXME: Decide the rules for casting to and from integers
        return canCast(exprType.backingType, to: targetType)

    default:
        return false
    }
}

func splatTuple(_ tuple: ty.Tuple) -> Type {
    if tuple.types.count == 1 {
        return tuple.types[0]
    }
    return tuple
}

/// A name space containing all type specifics
enum ty {

    // TODO: Use platform pointer types where appropriate

    struct Void: Type {
        var width: Int? { return 0 }
        var isNoReturn: Bool

        init(isNoReturn: Bool = false) {
            self.isNoReturn = isNoReturn
        }
    }

    struct Boolean: Type, NamableType {
        var width: Int?
    }

    struct Integer: Type, NamableType {
        var width: Int?
        var isSigned: Bool
    }

    struct Float: Type, NamableType {
        var width: Int?
    }

    struct Pointer: Type, NamableType {
        var width: Int? { return platformPointerWidth }
        var pointeeType: Type

        init(_ pointeeType: Type) {
            self.pointeeType = pointeeType
        }
    }

    struct Array: Type, NamableType {
        var width: Int? { return elementType.width! * length }
        var length: Int!
        var elementType: Type

        init(length: Int!, elementType: Type) {
            self.length = length
            self.elementType = elementType
        }
    }

    struct Slice: Type, NamableType /*, IRNamableType */ {
        var width: Int? { return 3 * platformPointerWidth } // pointer, length, capacity
        var elementType: Type
        var flags: Flags = .none

        init(_ elementType: Type, flags: Flags = .none) {
            self.elementType = elementType
            self.flags = flags
        }

        struct Flags: OptionSet {
            var rawValue: UInt64

            static let none   = Flags(rawValue: 0b0)
            static let string = Flags(rawValue: 0b1)
        }
    }

    struct Vector: Type, NamableType {
        var width: Int? { return elementType.width! * size }
        var size: Int
        var elementType: Type

        init(size: Int, elementType: Type) {
            self.size = size
            self.elementType = elementType
        }
    }

    struct Anyy: Type {
        var width: Int? { return platformPointerWidth * 2 }
    }

    struct Struct: Type, NamableType /*, IRNamableType */ {
        var width: Int?
        var flags: Flags
        var node: Node
        var fields: OrderedDictionary<String, Field>

        var isPolymorphic: Bool

        init(width: Int, flags: Flags, node: Node, fields: [Field], isPolymorphic: Bool = false) {
            self.width = width
            self.flags = flags
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

        struct Flags: OptionSet {
            var rawValue: UInt8

            static let none   = Flags(rawValue: 0b0000)
            static let packed = Flags(rawValue: 0b0001)
        }
    }

    struct Union: Type, NamableType /*, IRNamableType */ {
        var width: Int?
        var flags: Flags
        var tagType: Integer
        var dataType: Integer // NOTE: Array type may be better to allow control over alignment
        var cases: OrderedDictionary<String, Case>

        /// - Parameter tagWidth: if nil width is inferred from number of cases
        init(width: Int, tagWidth: Int? = nil, flags: Flags = .none, cases: [Case]) {
            self.width = width
            self.tagType = ty.Integer(width: tagWidth ?? positionOfHighestBit(cases.count), isSigned: false)
            if flags.contains(.inlineTag) {
                self.dataType = ty.Integer(width: width, isSigned: false)
            } else {
                self.dataType = ty.Integer(width: width - tagType.width!, isSigned: false)
            }
            self.flags = flags
            self.cases = [:]
            for c in cases {
                self.cases[c.ident.name] = c
            }
        }

        struct Case {
            var ident: Ident
            var type: Type
            var tag: Int
        }

        struct Flags: OptionSet {
            var rawValue: UInt8

            static let none      = Flags(rawValue: 0b0000)
            static let inlineTag = Flags(rawValue: 0b0001)
        }
    }

    struct Enum: Type, NamableType {
        var width: Int?
        var backingType: ty.Integer
        var isFlags: Bool
        var cases: OrderedDictionary<String, Case>

        init(width: Int, backingType: ty.Integer?, isFlags: Bool, cases: [Case]) {
            self.width = width
            self.backingType = backingType ?? ty.Integer(width: highestBitForValue(cases.count), isSigned: false)
            self.isFlags = isFlags
            self.cases = [:]
            for c in cases {
                self.cases[c.ident.name] = c
            }
        }

        struct Case {
            var ident: Ident
            let value: Expr?
            let constant: IntegerConstant
        }
    }

    struct Function: Type, NamableType {
        var node: FuncLit?
        var labels: [Ident]?
        var params: [Type]
        var returnType: Tuple
        var flags: Flags

        var width: Int? {
            return platformPointerWidth
        }

        struct Flags: OptionSet {
            var rawValue: UInt8

            static let none         = Flags(rawValue: 0b0000)
            static let variadic     = Flags(rawValue: 0b0001)
            static let cVariadic    = Flags(rawValue: 0b0011)
            static let polymorphic  = Flags(rawValue: 0b0100)
            static let builtin      = Flags(rawValue: 0b1000)
        }

        static func make(_ params: [Type], _ returnType: [Type], _ flags: Flags = .builtin) -> Function {
            return Function(node: nil, labels: nil, params: params, returnType: ty.Tuple.init(width: nil, types: returnType), flags: flags)
        }
    }

    struct UntypedInteger: Type, CustomStringConvertible {
        var width: Int? { return 64 } // NOTE: Bump up to larger size for more precision.
    }

    struct UntypedFloat: Type {
        var width: Int? { return 64 }
    }

    // sourcery:noinit
    class Named: Type {
        var entity: Entity
        var base: NamableType!
        var width: Int? {
            return base.width
        }

        init(entity: Entity, base: NamableType!) {
            self.entity = entity
            self.base = base
        }
    }

    struct Metatype: Type {
        var instanceType: Type

        init(instanceType: Type) {
            self.instanceType = instanceType
        }
    }

    struct Polymorphic: Type {
        var entity: Entity
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
        // NOTE: Give invalid a width to prevent crashes
        var width: Int? { return 1 }
        static let instance = Invalid()
    }

    struct File: Type {
        let memberScope: Scope

        init(memberScope: Scope) {
            self.memberScope = memberScope
        }
    }
}

extension ty.Union {

    func tag(for name: String) -> Int {
        return cases.orderedKeys.index(where: { $0 == name })!
    }
}

func isUntypedNumber(_ type: Type) -> Bool {
    return type is ty.UntypedInteger || type is ty.UntypedFloat
}

func isNumber(_ type: Type) -> Bool {
    return isUntypedNumber(type) || isInteger(type) || isFloat(type)
}

func isVoid(_ type: Type) -> Bool {
    return type is ty.Void
}

func isBoolean(_ type: Type) -> Bool {
    return baseType(type) is ty.Boolean
}

func isInteger(_ type: Type) -> Bool {
    let type = baseType(type)
    return type is ty.Integer || type is ty.UntypedInteger
}

func isSigned(_ type: Type) -> Bool {
    let type = baseType(type)
    return type is ty.UntypedInteger || (type as? ty.Integer)?.isSigned ?? false
}

func isFloat(_ type: Type) -> Bool {
    let type = baseType(type)
    return type is ty.Float || type is ty.UntypedFloat
}

func isPointer(_ type: Type) -> Bool {
    return baseType(type) is ty.Pointer
}

func isArray(_ type: Type) -> Bool {
    return baseType(type) is ty.Array
}

func isSlice(_ type: Type) -> Bool {
    return baseType(type) is ty.Slice
}

func isVector(_ type: Type) -> Bool {
    return baseType(type) is ty.Vector
}

func isAnyy(_ type: Type) -> Bool {
    return type is ty.Anyy
}

func isStruct(_ type: Type) -> Bool {
    return baseType(type) is ty.Struct
}

func isUnion(_ type: Type) -> Bool {
    return baseType(type) is ty.Union
}

func isEnum(_ type: Type) -> Bool {
    return baseType(type) is ty.Enum
}

func isEnumFlags(_ type: Type) -> Bool {
    return (baseType(type) as? ty.Enum)?.isFlags == true
}

func isFunction(_ type: Type) -> Bool {
    return baseType(type) is ty.Function
}

func isUntypedInteger(_ type: Type) -> Bool {
    return type is ty.UntypedInteger
}

func isUntypedFloat(_ type: Type) -> Bool {
    return type is ty.UntypedFloat
}

func isNamed(_ type: Type) -> Bool {
    return type is ty.Named
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

func isFile(_ type: Type) -> Bool {
    return type is ty.File
}

func isNoReturn(_ type: Type) -> Bool {
    return (type as? ty.Void)?.isNoReturn ?? false
}

func isNilable(_ type: Type) -> Bool {
    return baseType(type) is ty.Pointer
}

func isEquatable(_ type: Type) -> Bool {

    switch baseType(type) {
    case is ty.UntypedInteger, is ty.UntypedFloat:
        return true

    case is ty.Integer, is ty.Float:
        return true

    case is ty.Pointer:
        return true

    case is ty.Enum:
        return true

    case let vector as ty.Vector:
        return isEquatable(vector.elementType)
    // TODO: Make Slices & Arrays comparable where the element types are comparible

    default:
        return false
    }
}

func isComparable(_ type: Type) -> Bool {
    return isInteger(type) || isFloat(type)
}
