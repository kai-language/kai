import LLVM

protocol Type: CustomStringConvertible {
    var width: Int? { get }
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
    case (let lhs as ty.Named, let rhs as ty.Named):
        return lhs.underlying == rhs.underlying
    case (let lhs as ty.Integer, let rhs as ty.Integer):
        return lhs.isSigned == rhs.isSigned && lhs.width == rhs.width
    case (is ty.FloatingPoint, is ty.FloatingPoint):
        return lhs.width == rhs.width
    case (let lhs as ty.Pointer, let rhs as ty.Pointer):
        return lhs.pointeeType == rhs.pointeeType
    case (let lhs as ty.Array, let rhs as ty.Array):
        return lhs.elementType == rhs.elementType && lhs.length == rhs.length
    case (let lhs as ty.DynamicArray, let rhs as ty.DynamicArray):
        return lhs.elementType == rhs.elementType
    case (let lhs as ty.Struct, let rhs as ty.Struct):
        return lhs.node.start == rhs.node.start
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

func canConvert(_ lhs: Type, to rhs: Type) -> Bool {

    if lhs is ty.Metatype || rhs is ty.Metatype {
        // If either the left or right side is a `type` as denoted by an empty tuple
        return ((rhs as? ty.Metatype)?.instanceType as? ty.Tuple)?.types.count == 0 ||
               ((lhs as? ty.Metatype)?.instanceType as? ty.Tuple)?.types.count == 0
    }
    if let lhs = lhs as? ty.Metatype, let rhs = rhs as? ty.Metatype {
        return canConvert(lhs.instanceType, to: rhs.instanceType)
    }
    if let lhs = lhs as? ty.Tuple, lhs.types.count == 1 {
        return canConvert(lhs.types[0], to: rhs)
    }
    if let rhs = rhs as? ty.Tuple, rhs.types.count == 1 {
        return canConvert(rhs.types[0], to: lhs)
    }
    if let lhs = lhs as? ty.Array, let rhs = rhs as? ty.Pointer {
        return canConvert(lhs.elementType, to: rhs.pointeeType)
    }
    return lhs == rhs
}

/// A name space containing all type specifics
enum ty {

    struct Void: Type {
        var width: Int? { return 0 }
    }

    struct Boolean: Type {
        var width: Int? { return 1 }
    }

    struct Integer: Type {
        var width: Int?
        var isSigned: Bool
    }

    struct FloatingPoint: Type {
        var width: Int?
    }

    struct KaiString: Type {
        var width: Int? { return 64 * 3 } // pointer, length, capacity
    }

    struct Pointer: Type {
        var width: Int? { return MemoryLayout<Int>.size * 8 }
        var pointeeType: Type

        init(pointeeType: Type) {
            self.pointeeType = pointeeType
        }
    }

    struct Array: Type {
        var width: Int? { return (elementType.width ?? 1) * length }
        var length: Int
        var elementType: Type

        init(length: Int, elementType: Type) {
            self.length = length
            self.elementType = elementType
        }
    }

    struct DynamicArray: Type {
        // TODO: calculate correct `struct` size
        var width: Int? { return MemoryLayout<Int>.size }
        var elementType: Type
        var initialLength: Int!
        var initialCapacity: Int!

        init(elementType: Type, initialLength: Int!, initialCapacity: Int!) {
            self.elementType = elementType
            self.initialLength = initialLength
            self.initialCapacity = initialCapacity
        }
    }

    struct Anyy: Type {
        var width: Int? { return 64 }
    }

    struct Struct: Type {
        var width: Int?

        var node: Node
        var fields: [Field] = []
        var isPolymorphic: Bool

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

    struct Function: Type {
        var node: FuncLit?
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

    struct Named: Type {
        var entity: Entity
        var underlying: Type
        var width: Int? { return underlying.width }
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
