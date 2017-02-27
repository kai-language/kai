
class Scope {
    weak var parent: Scope?
    var prev: Scope?
    var next: Scope?
    var children: [Scope?] = []
    var elements: [String: Entity] = [:]
    var implicit: [Entity: Bool] = [:]

    var shared: [Scope] = []
    var imported: [Scope] = []
    var isProc:   Bool = false
    var isGlobal: Bool = false
    var isFile:   Bool = false
    var isInit:   Bool = false
    /// Only relevant for file scopes
    var hasBeenImported: Bool = false

    var file: ASTFile?

    static var universal: Scope = {

        var s = Scope(parent: nil)

        // TODO(vdka): Insert types into universal scope

        for type in BasicType.allBasicTypes {
            let e = Entity(kind: .typeName, flags: [], scope: s, location: nil, identifier: nil)
            s.insert(e, named: type.name)
        }


        Entity.declareBuiltinConstant(name: "true", value: .bool(true), scope: s)
        Entity.declareBuiltinConstant(name: "false", value: .bool(true), scope: s)

        let e = Entity(kind: .nil, scope: s, location: nil, identifier: nil)
        e.type = Type.unconstrNil
        s.insert(e, named: "nil")

        return s
    }()

    init(parent: Scope?) {
        self.parent = parent
    }
}

extension Scope {

    // NOTE(vdka): Should this return an error?
    func insert(_ entity: Entity, named name: String) {

        guard !elements.keys.contains(name) else {
            reportError("Conflicting definition", at: entity.location ?? .unknown)
            return
        }

        elements[name] = entity
    }

    func lookup(_ name: String) -> Entity? {

        if let entity = elements[name] {
            return entity
        } else {
            return parent?.lookup(name)
        }
    }
}

struct DeclInfo {

    unowned var scope: Scope

    var entities: [Entity]

    var typeExpr: AstNode
    var initExpr: AstNode
    var procLit:  AstNode // AstNode_ProcLit

    /// The entities this entity requires to exist
    var deps: Set<Entity>
}
