import LLVM

final class Type: Hashable, CustomStringConvertible {
    weak var entity: Entity?
    var width: Int?

    var flags: Flag = .none

    var value: TypeValue
    var kind: TypeKind {
        return Swift.type(of: value).typeKind
    }

    init<T: TypeValue>(value: T, entity: Entity? = nil) {
        self.entity = entity
        self.width = nil
        self.value = value
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        static let none = Flag(rawValue: 0b0000_0000)
        static let used = Flag(rawValue: 0b0000_0001)
    }

    var description: String {
        return "placeholder"
    }

    var name: String {
        return description
    }

    var isVoid: Bool {
        return kind == .void || (kind == .tuple && (asTuple.types.isEmpty || asTuple.types[0].isVoid))
    }

    var isAny: Bool {
        return kind == .any
    }

    var isCVargAny: Bool {
        return kind == .cvargsAny
    }

    var isBoolean: Bool {
        return kind == .boolean
    }

    var isBooleanesque: Bool {
        return isBoolean || isNumber
    }

    var isNumber: Bool {
        return isInteger || isFloatingPoint
    }

    var isInteger: Bool {
        return kind == .integer
    }

    var isSignedInteger: Bool {
        return asInteger.isSigned
    }

    var isUnsignedInteger: Bool {
        return asInteger.isSigned == false
    }

    var isFloatingPoint: Bool {
        return kind == .floatingPoint
    }

    var isFunction: Bool {
        return kind == .function
    }

    var isFunctionPointer: Bool {
        return kind == .pointer && asPointer.pointeeType.isFunction
    }

    var isTuple: Bool {
        return kind == .tuple
    }

    var isPolymorphic: Bool {
        return kind == .polymorphic
    }

    var isMetatype: Bool {
        return kind == .metatype
    }

    func compatibleWithoutExtOrTrunc(_ type: Type) -> Bool {
        return type == self
    }

    func compatibleWtihExtOrTrunc(_ type: Type) -> Bool {
        if type.isInteger && self.isInteger {
            return true
        }

        if type.isFloatingPoint && self.isFloatingPoint {
            return true
        }

        return false
    }

    static func lowerFromMetatype(_ type: Type) -> Type {
        return type.asMetatype.instanceType
    }

// sourcery:inline:auto:Type.Init
init(entity: Entity?, width: Int?, flags: Flag, value: TypeValue) {
    self.entity = entity
    self.width = width
    self.flags = flags
    self.value = value
}
// sourcery:end
}

enum TypeKind {
    case void
    case any
    case cvargsAny
    case integer
    case floatingPoint
    case boolean
    case function
    case `struct`
    case tuple
    case pointer
    case polymorphic
    case metatype
    case file
}

protocol TypeValue {
    static var typeKind: TypeKind { get }
}

extension Type {
    struct Void: TypeValue {
        static let typeKind: TypeKind = .void
    }

    struct `Any`: TypeValue {
        static let typeKind: TypeKind = .any
    }

    struct CVargsAny: TypeValue {
        static let typeKind: TypeKind = .cvargsAny
    }

    struct Integer: TypeValue {
        static let typeKind: TypeKind = .integer
        var isSigned: Bool
    }

    struct FloatingPoint: TypeValue {
        static let typeKind: TypeKind = .floatingPoint
    }

    struct Boolean: TypeValue {
        static let typeKind: TypeKind = .boolean
    }

    struct Function: TypeValue {
        static let typeKind: TypeKind = .function

        var node: Node
        var params: [Type]
        /// - Note: Always a tuple type.
        var returnType: Type
        var flags: Flag

        var isVariadic: Bool { return flags.contains(.variadic) }
        var isCVariadic: Bool { return flags.contains(.cVariadic) }
        var needsSpecialization: Bool { return flags.contains(.polymorphic) }
        var isBuiltin: Bool { return flags.contains(.builtin) }

        struct Flag: OptionSet {
            var rawValue: UInt8

            static let none         = Flag(rawValue: 0b0000)
            static let variadic     = Flag(rawValue: 0b0001)
            static let cVariadic    = Flag(rawValue: 0b0011)
            static let polymorphic  = Flag(rawValue: 0b0100)
            static let builtin      = Flag(rawValue: 0b1000)
        }
    }

    struct Struct: TypeValue {
        static let typeKind: TypeKind = .struct

        var node: Node
        var fields: [Field] = []

        struct Field {
            let ident: Ident
            let type: Type

            var index: Int
            var offset: Int

            var name: String {
                return ident.name
            }
        }
    }

    struct Tuple: TypeValue {
        static let typeKind: TypeKind = .tuple

        var types: [Type]
    }

    struct Pointer: TypeValue {
        static let typeKind: TypeKind = .pointer

        let pointeeType: Type
    }

    struct Polymorphic: TypeValue {
        static let typeKind: TypeKind = .polymorphic
    }

    struct Metatype: TypeValue {
        static let typeKind: TypeKind = .metatype

        let instanceType: Type
    }

    struct File: TypeValue {
        static let typeKind: TypeKind = .file

        let memberScope: Scope
    }
}

extension Type {
    var memberScope: Scope? {
        switch self.kind {
        case .file:
            return asFile.memberScope
        default:
            return nil
        }
    }
}

extension Type {
    var hashValue: Int {
        return unsafeBitCast(self, to: Int.self)
    }

    static func ==(lhs: Type, rhs: Type) -> Bool {
        return false
    }
}
