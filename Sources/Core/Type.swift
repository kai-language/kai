import LLVM

protocol Type {
    var width: Int? { get }
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
         (is ty.Boolean, is ty.Boolean):
        return true
    case (let lhs as ty.Integer, let rhs as ty.Integer):
        return lhs.isSigned == rhs.isSigned && lhs.width == rhs.width
    case (is ty.FloatingPoint, is ty.FloatingPoint):
        return lhs.width == rhs.width
    case (let lhs as ty.Pointer, let rhs as ty.Pointer):
        return lhs.pointeeType == rhs.pointeeType
    case (let lhs as ty.Struct, let rhs as ty.Struct):
        return lhs.node.start == rhs.node.start
    case (let lhs as ty.Function, let rhs as ty.Function):
        return lhs.params == rhs.params && lhs.returnType == rhs.returnType
    case (let lhs as ty.Tuple, let rhs as ty.Tuple):
        return lhs.types == rhs.types
    case (let lhs as ty.Metatype, let rhs as ty.Metatype):
        return lhs.instanceType == rhs.instanceType
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

    if lhs is ty.Type {
        return rhs is ty.Metatype || (rhs as! ty.Metatype).entity === BuiltinType.type.entity
    }
    if let lhs = lhs as? ty.Metatype, lhs.entity === BuiltinType.type.entity {
        return (rhs as? ty.Metatype)?.entity === BuiltinType.type.entity
    }
    if let rhs = rhs as? ty.Metatype, rhs.entity === BuiltinType.type.entity {
        return (lhs as? ty.Metatype)?.entity === BuiltinType.type.entity
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
    return lhs == rhs
}

/// A name space containing all type specifics
enum ty {

    struct Void: Type {
        var width: Int? = 0
    }

    struct Boolean: Type {
        var width: Int? = 1
    }

    struct Integer: Type {
        var width: Int? = 0
        var isSigned: Bool
    }

    struct FloatingPoint: Type {
        var width: Int? = nil
    }

    struct Pointer: Type {
        var width: Int? = MemoryLayout<Int>.size
        var pointeeType: Type

        init(pointeeType: Type) {
            self.pointeeType = pointeeType
        }
    }

    struct Struct: Type {
        var width: Int? = 0

        var node: Node
        var fields: [Field] = []

        /// Used for the named type
        var ir: Ref<IRType?>

        struct Field {
            let ident: Ident
            let type: Type

            var index: Int
            var offset: Int

            var name: String {
                return ident.name
            }
        }

        static func make(named name: String, builder: IRBuilder, _ members: [(String, Type)]) -> Type {

            var width = 0
            var fields: [Struct.Field] = []
            for (index, (name, type)) in members.enumerated() {

                let ident = Ident(start: noPos, name: name, entity: nil)

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

            irType.setBody(irTypes)

            let type = Struct(width: width, node: Empty(semicolon: noPos, isImplicit: true), fields: fields, ir: Ref(irType))
            return Metatype(instanceType: type)
        }
    }

    struct Function: Type {
        var width: Int? = 0

        var node: FuncLit
        var params: [Type]
        var returnType: Type
        var flags: Flags

        var isVariadic: Bool { return flags.contains(.variadic) }
        var isCVariadic: Bool { return flags.contains(.cVariadic) }
        var needsSpecialization: Bool { return flags.contains(.polymorphic) }
        var isBuiltin: Bool { return flags.contains(.builtin) }

        struct Flags: OptionSet {
            var rawValue: UInt8

            static let none         = Flags(rawValue: 0b0000)
            static let variadic     = Flags(rawValue: 0b0001)
            static let cVariadic    = Flags(rawValue: 0b0011)
            static let polymorphic  = Flags(rawValue: 0b0100)
            static let builtin      = Flags(rawValue: 0b1000)
        }
    }

    struct Tuple: Type {
        var width: Int?
        var types: [Type]

        static func make(_ types: [Type]) -> Type {

            let width = types.map({ $0.width ?? 0 }).reduce(0, +)

            let type = Tuple(width: width, types: types)

            return type
        }
    }

    struct Polymorphic: Type {
        var width: Int? = nil
    }

    struct Metatype: Type {
        weak var entity: Entity? = nil
        var width: Int? = nil
        var instanceType: Type

        init(instanceType: Type) {
            self.instanceType = instanceType
        }
    }

    struct Invalid: Type {
        static let instance = Invalid()
        var width: Int? = nil
    }

    struct Anyy: Type {
        var width: Int? = 64
    }

    struct CVarArg: Type {
        static let instance = CVarArg()
        var width: Int? = nil
    }

    struct File: Type {
        var width: Int? = nil
        let memberScope: Scope

        init(memberScope: Scope) {
            self.memberScope = memberScope
        }
    }
}
