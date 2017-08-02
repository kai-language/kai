class Entity: CustomStringConvertible {
    var ident: Ident
    var type: Type?
    var flags: Flag = .none

    var memberScope: Scope?

    var owningScope: Scope!

    var name: String {
        return ident.name
    }

    init(ident: Ident) {
        self.ident = ident
    }

    var description: String {
        return name
    }

// sourcery:inline:auto:Entity.Init
init(ident: Ident, type: Type?, flags: Flag, memberScope: Scope?, owningScope: Scope!) {
    self.ident = ident
    self.type = type
    self.flags = flags
    self.memberScope = memberScope
    self.owningScope = owningScope
}
// sourcery:end
}
