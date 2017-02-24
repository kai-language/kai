
#if false
import LLVM

extension TypeRecord {

    convenience init(basicType: BasicType) {

        self.init(name: basicType.name, kind: .basic(basicType), source: .llvm)
    }

    // TODO(vdka): Add others

    static let invalid         = TypeRecord(basicType: .invalid)

    static let void            = TypeRecord(basicType: .void)

    static let bool            = TypeRecord(basicType: .bool)

    static let i8              = TypeRecord(basicType: .i8)
    static let u8              = TypeRecord(basicType: .u8)
    static let i16             = TypeRecord(basicType: .i16)
    static let u16             = TypeRecord(basicType: .u16)
    static let i32             = TypeRecord(basicType: .i32)
    static let u32             = TypeRecord(basicType: .u32)
    static let i64             = TypeRecord(basicType: .i64)
    static let u64             = TypeRecord(basicType: .u64)
    static let f32             = TypeRecord(basicType: .f32)
    static let f64             = TypeRecord(basicType: .f64)
    static let int             = TypeRecord(basicType: .int)
    static let uint            = TypeRecord(basicType: .uint)

    static let rawptr          = TypeRecord(basicType: .rawptr)
    static let string          = TypeRecord(basicType: .string)

    static let unconstrBoolean = TypeRecord(basicType: .unconstrBoolean)
    static let unconstrInteger = TypeRecord(basicType: .unconstrInteger)
    static let unconstrFloat   = TypeRecord(basicType: .unconstrFloat)
    static let unconstrString  = TypeRecord(basicType: .unconstrString)
    static let unconstrNil     = TypeRecord(basicType: .unconstrNil)

    /// Returns the default type for unconstrained types or does nothing.
    var defaultType: TypeRecord {
        guard case .basic(let basicType) = self.kind else { return self }
        switch basicType.kind {
        case .unconstrained(.bool):
            return .bool

        case .unconstrained(.integer):
            return .int

        case .unconstrained(.float):
            return .f64

        case .unconstrained(.string):
            return .string

        case .unconstrained(.nil):
            return .unconstrNil // Nil cannot be constrained.

        default:
            return self
        }
    }
}

extension TypeRecord: Equatable {

    static func == (lhs: TypeRecord, rhs: TypeRecord) -> Bool {
        guard lhs.node === rhs.node else { return false }
        switch (lhs.kind, rhs.kind) {
        case let (.struct(lhs), .struct(rhs)):
            return lhs == rhs

        case let (.enum(lhs), .enum(rhs)):
            return lhs == rhs

        default:
            return false
        }
    }
}

extension TypeRecord: CustomStringConvertible {

    var description: String {

        switch self.kind {
        case .basic(let basicType):
            return basicType.name

        case .alias(let referencedType):
            return "alias \(referencedType.description)"

        case .struct(_):
            return "struct"

        case .enum(_):
            return "enum"

        case .proc(let procInfo):

            var desc = "("
            desc += procInfo.params.map({ $0.description }).joined(separator: ", ")
            desc += ")"

            desc += " -> "
            desc += procInfo.returns.map({ $0.description }).joined(separator: ", ")

            return desc

        case .invalid:
            return "invalid"

        default:
            unimplemented()
        }
    }
}
#endif
