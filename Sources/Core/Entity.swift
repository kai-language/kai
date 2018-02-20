import LLVM

class Entity: CustomStringConvertible {
    var ident: Ident
    var type: Type?
    var flags: Flag = .none
    var constant: Value?
    var file: SourceFile?
    var package: SourcePackage? {
        return file?.package
    }

    var memberScope: Scope?

    var owningScope: Scope!

    var callconv: String?
    var linkname: String?

    var declaration: Decl?
    var dependencies: [Decl]!

    // set in IRGen
    var mangledName: String!
    var value: IRValue?

    var name: String {
        return ident.name
    }

    struct Flag: OptionSet {
        let rawValue: UInt16
        static let none         = Flag(rawValue: 0b0000)

        // the highest 4 bits are used as control flags
        static let builtin      = Flag(rawValue: 0b0111 << 12) // implies checked & emitted
        static let checked      = Flag(rawValue: 0b0010 << 12)

        // entity info
        static let file          = Flag(rawValue: 0b00000001)
        static let library       = Flag(rawValue: 0b00000010)
        static let type          = Flag(rawValue: 0b00000100)
        static let constant      = Flag(rawValue: 0b00001000)
        static let implicitType  = Flag(rawValue: 0b00011100) // implies constant & type
        static let foreign       = Flag(rawValue: 0b00100000)
        static let label         = Flag(rawValue: 0b01000000)
        static let field         = Flag(rawValue: 0b10000000)
        static let parameter     = Flag(rawValue: 0b00000001 << 8)
        static let polyParameter = Flag(rawValue: 0b00000011 << 8)
    }

    var description: String {
        return name
    }

    init(ident: Ident, type: Type?, flags: Flag = .none) {
        self.ident = ident
        self.type = type
        self.flags = flags
    }

// sourcery:inline:auto:Entity.Init
init(ident: Ident, type: Type? = nil, flags: Flag, constant: Value? = nil, file: SourceFile? = nil, memberScope: Scope? = nil, owningScope: Scope! = nil, callconv: String? = nil, linkname: String? = nil, declaration: Decl? = nil, dependencies: [Decl]! = nil, mangledName: String! = nil, value: IRValue? = nil) {
    self.ident = ident
    self.type = type
    self.flags = flags
    self.constant = constant
    self.file = file
    self.memberScope = memberScope
    self.owningScope = owningScope
    self.callconv = callconv
    self.linkname = linkname
    self.declaration = declaration
    self.dependencies = dependencies
    self.mangledName = mangledName
    self.value = value
}
// sourcery:end
}

/// Traverses the expr returning the entity if it is an Identifier or a selector on a file entity
func entity(from expr: Expr) -> Entity? {
    switch expr {
    case let expr as Ident:
        return expr.entity

    case let expr as Selector:
        guard case .file(let entity)? = expr.checked else {
            return nil
        }
        return entity

    default:
        return nil
    }
}

extension Entity {

    static func makeAnonLabel() -> Entity {
        let entity = copy(Entity.anonymous)
        entity.flags.insert(.label)
        return entity
    }

    static let invalid = Entity.makeBuiltin("< invalid >")
}

extension Entity: Hashable {

    var hashValue: Int {
        // use the class pointer
        return unsafeBitCast(self, to: Int.self)
    }

    static func ==(lhs: Entity, rhs: Entity) -> Bool {
        return lhs === rhs
    }
}
