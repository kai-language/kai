
// sourcery: noinit
final class Scope {
    weak var parent: Scope?

    var owningNode: Node?

    var isFile: Bool
    var isPackage: Bool

    var members: [Entity] = []

    init(parent: Scope? = nil, owningNode: Node? = nil, isFile: Bool = false, isPackage: Bool = false, members: [Entity] = []) {
        self.parent = parent
        self.owningNode = owningNode
        self.isFile = isFile
        self.isPackage = isPackage
        self.members = members
    }

    func lookup(_ name: String) -> Entity? {
        if let found = members.first(where: { $0.name == name }) {
            return found
        }

        return parent?.lookup(name)
    }

    /// - Note: Returns previous
    func insert(_ entity: Entity, scopeOwnsEntity: Bool = true) -> Entity? {
        if let existing = members.first(where: { $0.name == entity.name }) {
            return existing
        }

        if scopeOwnsEntity {
            entity.owningScope = self
        }

        members.append(entity)
        return nil
    }

    static let global: Scope = {
        // declare all builtin types
        for builtin in ty.builtin {
            builtin.entity.type = ty.Metatype(instanceType: builtin.type)
        }
        return Scope(members: builtins)
    }()
}
