
// sourcery: noinit
final class Scope {
    weak var parent: Scope?

    var owningNode: Node?

    var isFile: Bool
    var isPackage: Bool

    var members: [String: Entity] = [:]

    init(parent: Scope? = nil, owningNode: Node? = nil, isFile: Bool = false, isPackage: Bool = false, members: [String: Entity] = [:]) {
        self.parent = parent
        self.owningNode = owningNode
        self.isFile = isFile
        self.isPackage = isPackage
        self.members = members
    }

    func lookup(_ name: String) -> Entity? {
        return members[name] ?? parent?.lookup(name)
    }

    /// - Note: Returns previous
    func insert(_ entity: Entity, scopeOwnsEntity: Bool = true) -> Entity? {
        if let existing = members[entity.name] {
            return existing
        }

        if scopeOwnsEntity {
            entity.owningScope = self
        }

        members[entity.name] = entity
        return nil
    }
}
