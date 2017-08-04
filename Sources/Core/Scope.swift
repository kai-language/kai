// sourcery: noinit
final class Scope {
    weak var parent: Scope?

    var owningNode: Node?

    var file: SourceFile?
    var isFile: Bool {
        return file != nil
    }

    var members: [Entity] = []

    init(parent: Scope? = nil, owningNode: Node? = nil, file: SourceFile? = nil, members: [Entity] = []) {
        self.parent = parent
        self.owningNode = owningNode
        self.file = file
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

    // TODO: builtins
    static let global = Scope(members: [])
}
