
import LLVM

#if false

enum ExactValue: Equatable {
    case invalid
    case bool(Bool)
    case string(String)
    case integer(Int64)
    case float(Double)

    static func ==(lhs: ExactValue, rhs: ExactValue) -> Bool {
        switch (lhs, rhs) {
        case let (.bool(l), .bool(r)):
            return l == r

        case let (.string(l), .string(r)):
            return l == r

        case let (.integer(l), .integer(r)):
            return l == r

        case let (.float(l), .float(r)):
            return l == r

        default:
            return false
        }
    }
}

class Entity {
    var kind: Kind
    var flags: Flag
    var name: String
    var location: SourceLocation
    unowned var scope: Scope

    /// Set in the checker
    var type: Type? = nil
    var identifier: AstNode?
    var llvm: IRValue?

    init(kind: Kind = .invalid, name: String, location: SourceLocation? = nil, flags: Flag = [], scope: Scope, identifier: AstNode?) {
        self.kind = kind
        self.name = name
        self.flags = flags
        self.scope = scope
        self.location = location ?? identifier?.startLocation ?? .unknown
        self.type = nil
        self.identifier = identifier
    }

    static func declareBuiltinConstant(name: String, value: ExactValue, scope: Scope) {
        var type: Type
        switch value {
        case .invalid:
            type = .invalid

        case .bool(_):
            type = .unconstrBoolean

        case .float(_):
            type = .unconstrFloat

        case .integer(_):
            type = .unconstrInteger

        case .string(_):
            type = .unconstrString
        }

        let e = Entity(kind: .compileTime(value), name: name, location: .unknown, scope: scope, identifier: nil)
        e.type = type

        scope.insert(e)
    }
}

extension Entity {
    var isExported: Bool {
        switch kind {
        case .builtin,
             .importName,
             .libraryName,
             .nil:
            return false

        default:
            return true
        }
    }
}

extension Entity: Hashable {

    static func ==(lhs: Entity, rhs: Entity) -> Bool {
        return lhs.kind == rhs.kind &&
            lhs.flags == rhs.flags &&
            lhs.location == rhs.location &&
            lhs.scope === rhs.scope &&
            lhs.type === rhs.type
    }

    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

extension Entity {

    enum Kind: Equatable {
        case invalid
        case compileTime(ExactValue)
        case runtime
        case typeName
        case procedure // (isForeign (foreignDetails), tags, overload: OverloadKind)
        case builtin
        case importName  //path, name: String, scope: Scope, used: Bool)
        case libraryName // (path, name: String, used: Bool)
        case `nil`

        static func ==(lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case (.runtime, .runtime),
                 (.typeName, .typeName),
                 (.procedure, .procedure),
                 (.builtin, .builtin),
                 (.importName, .importName),
                 (.libraryName, .libraryName),
                 (.nil, .nil):
                return true

            case let (.compileTime(l), .compileTime(r)):
                return l == r

            default:
                return false
            }
        }
    }

    struct Flag: OptionSet {
        var rawValue: UInt16

        static let visited   = Flag(rawValue: 0b00000001)
        static let used      = Flag(rawValue: 0b00000010)
        static let anonymous = Flag(rawValue: 0b00000100)
        static let field     = Flag(rawValue: 0b00001000)
        static let param     = Flag(rawValue: 0b00010000)
        static let ellipsis  = Flag(rawValue: 0b00100000)
        static let noAlias   = Flag(rawValue: 0b01000000)
        static let typeField = Flag(rawValue: 0b10000000)
    }
}

#endif
