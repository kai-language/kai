import LLVM

class Entity: CustomStringConvertible {
    var ident: Ident
    var type: Type?
    var flags: Flag = .none

    var memberScope: Scope?

    var owningScope: Scope!

    var value: IRValue?

    var name: String {
        return ident.name
    }

    struct Flag: OptionSet {
        let rawValue: UInt16
        static let none         = Flag(rawValue: 0b0000_0000)
        static let used         = Flag(rawValue: 0b0000_0001)
        static let file         = Flag(rawValue: 0b0000_0010)
        static let library      = Flag(rawValue: 0b0000_0100)
        static let type         = Flag(rawValue: 0b0001_0000)
        static let constant     = Flag(rawValue: 0b0010_0000)
        static let implicitType = Flag(rawValue: 0b0111_0000)
        static let foreign      = Flag(rawValue: 0b1000_0000)
        static let label        = Flag(rawValue: 0b0000_0001 << 8)
        static let builtinFunc  = Flag(rawValue: 0b0000_0010 << 8)
    }

    var description: String {
        return name
    }

// sourcery:inline:auto:Entity.Init
init(ident: Ident, type: Type?, flags: Flag, memberScope: Scope?, owningScope: Scope!, value: IRValue?) {
    self.ident = ident
    self.type = type
    self.flags = flags
    self.memberScope = memberScope
    self.owningScope = owningScope
    self.value = value
}
// sourcery:end
}

extension Entity {

    static func makeBuiltin(_ name: String, type: Type? = nil, flags: Flag = .none) -> Entity {

        let ident = Ident(start: noPos, name: name, entity: nil)
        let entity = Entity(ident: ident, type: type, flags: .constant, memberScope: nil, owningScope: nil, value: nil)
        return entity
    }

    static let invalid = Entity(ident: Ident(start: noPos, name: "<invalid>", entity: nil), type: nil, flags: .none, memberScope: nil, owningScope: nil, value: nil)
}
