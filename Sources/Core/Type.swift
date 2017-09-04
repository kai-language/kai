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
         (is ty.KaiString, is ty.KaiString):
        return true
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
        return (rhs as? ty.Metatype)?.entity === Entity.type || (lhs as? ty.Metatype)?.entity === Entity.type
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
        unowned var entity: Entity = .void
        var width: Int? { return 0 }
    }

    struct Boolean: Type {
        unowned var entity: Entity = .bool
        var width: Int? { return 1 }
    }

    struct Integer: Type {
        unowned var entity: Entity = .anonymous
        var width: Int?
        var isSigned: Bool
    }

    struct FloatingPoint: Type {
        unowned var entity: Entity = .anonymous
        var width: Int?
    }

    struct KaiString: Type {
        unowned var entity: Entity = .anonymous
        var width: Int? { return 64 * 3 } // pointer, length, capacity
    }

    struct Pointer: Type {
        unowned var entity: Entity = .anonymous
        var width: Int? { return MemoryLayout<Int>.size }
        var pointeeType: Type

        init(pointeeType: Type) {
            self.pointeeType = pointeeType
        }
    }

    struct Array: Type {
        unowned var entity: Entity = .anonymous
        var width: Int? { return (elementType.width ?? 1) * length }
        var length: Int
        var elementType: Type

        init(length: Int, elementType: Type) {
            self.length = length
            self.elementType = elementType
        }
    }

    struct DynamicArray: Type {
        unowned var entity: Entity = .anonymous
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
        unowned var entity: Entity = .any
        var width: Int? { return 64 }
    }

    struct Struct: Type {
        unowned var entity: Entity = .anonymous
        var width: Int?

        var node: Node
        var fields: [Field] = []

        /// Used for the named type
        var ir: Ref<LLVM.StructType?>

        struct Field {
            let ident: Ident
            let type: Type

            var index: Int
            var offset: Int

            var name: Swift.String {
                return ident.name
            }
        }

        static func make(named name: String, builder: IRBuilder, _ members: [(String, Type)]) -> BuiltinType {

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
            type = Struct(entity: entity, width: width, node: Empty(semicolon: noPos, isImplicit: true), fields: fields, ir: Ref(irType))
            type = Metatype(instanceType: type)

            entity.type = type
            return BuiltinType(entity: entity, type: type)
        }
    }

    struct Function: Type {
        unowned var entity: Entity = .anonymous
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

    struct Metatype: Type {
        unowned var entity: Entity = .anonymous
        var instanceType: Type

        init(instanceType: Type) {
            self.instanceType = instanceType
        }

        init(entity: Entity, instanceType: Type) {
            self.entity = entity
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
