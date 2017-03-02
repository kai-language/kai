
import LLVM

/// These are the basic types within the language.
struct BasicType {
    var kind: Kind
    var flags: Flag
    var size: Int64
    var name: String

    enum Kind {
        case invalid
        case void
        case bool

        case i8
        case u8
        case i16
        case u16
        case i32
        case u32
        case i64
        case u64

        case f32
        case f64

        case int
        case uint
        case rawptr
        case string

        case unconstrained(Unconstrained)

        enum Unconstrained {
            case bool
            case integer
            case float
            case string
            case `nil`
        }
    }

    struct Flag: OptionSet {
        var rawValue: UInt64
        init(rawValue: UInt64) { self.rawValue = rawValue }

        static let boolean        = Flag(rawValue: 0b00000001)
        static let integer        = Flag(rawValue: 0b00000010)
        static let unsigned       = Flag(rawValue: 0b00000100)
        static let float          = Flag(rawValue: 0b00001000)
        static let pointer        = Flag(rawValue: 0b00010000)
        static let string         = Flag(rawValue: 0b00100000)
        static let unconstrained  = Flag(rawValue: 0b01000000)

        static let none:     Flag = []
        static let numeric:  Flag = [.integer, .unsigned, .float]
        static let ordered:  Flag = [.numeric, .string, .pointer]
        static let constant: Flag = [.boolean, .numeric, .pointer, .string]
    }
}

/// TypeRecord is the metadata for a Type
class TypeRecord {

    var kind: Kind
    var node: AstNode

    init(kind: Kind, node: AstNode) {
        self.kind = kind
        self.node = node
    }

    enum Kind {
        case `struct`(fields: [Entity]) // TODO(vdka): needs more in the way of layout
        case `enum`(baseType: Type?, caseNames: [Entity])
    }
}

struct ProcInfo {
    var scope: AstNode?
    var labels: [(callsite: String?, binding: String)]?
    var params: [AstNode]
    var returns: [AstNode]
    var isVariadic: Bool
    var callingConvention: CallingConvention

    init(
        scope: AstNode? = nil,
        labels: [(callsite: String?, binding: String)]?,
        params: [AstNode],
        returns: [AstNode],
        isVariadic: Bool = false,
        callingConvention: CallingConvention = .kai) {

        self.scope = scope
        self.labels = labels
        self.params = params
        self.returns = returns
        self.isVariadic = isVariadic
        self.callingConvention = callingConvention
    }

    enum CallingConvention {
        case kai
        case c
    }
}

class Type {

    var kind: Kind

    /// TODO: Shouldn't this be computed off the kind?
    var isInvalid: Bool

    var llvm: IRType?

    init(kind: Kind, isInvalid: Bool = false) {
        self.kind = kind
        self.isInvalid = isInvalid
    }

    enum Kind {
        case invalid

        /// The basic types in most languages. Ints, Floats, string
        case basic(BasicType)

        case pointer(Type?)
        case array(Type?, count: Int)
        case dynArray(Type?)
        case record(TypeRecord)

        case named(String, base: Type?, typeName: Entity?)

        case proc(ProcInfo)
    }

    var isNamed: Bool {
        switch self.kind {
            case .basic(_), .named(_, base: _, typeName: _):
            return true

        default:
            return false
        }
    }
}

class TypePath {

    var path: [Type] = []
    var isInvalid: Bool

    init(path: [Type], isInvalid: Bool = false) {
        self.path = path
        self.isInvalid = isInvalid
    }

    func push(_ type: Type) {

        for currType in path {
            assert(currType.isNamed)
            if currType === type {
                guard case .named(_, base: _, typeName: let entity) = currType.kind else { preconditionFailure() }
                reportError("Illegal declaration cylce of \(type)", at: entity?.location ?? .unknown)
            }
        }
    }

}

// MARK: BasicType auxilary

extension BasicType: Equatable {

    static func == (lhs: BasicType, rhs: BasicType) -> Bool {
        return isMemoryEquivalent(lhs.kind, rhs.kind)
    }
}

// MARK: Static basic types
extension BasicType {

    static let invalid = BasicType(kind: .invalid, flags: [],         size: 0, name: "<invalid>")

    static let void    = BasicType(kind: .void,    flags: [],         size: 0, name: "void")

    static let bool    = BasicType(kind: .bool,    flags: [.boolean], size: 1, name: "bool")

    static let i8      = BasicType(kind: .i8,      flags: [.integer],            size: 1, name: "i8")
    static let u8      = BasicType(kind: .u8,      flags: [.integer, .unsigned], size: 1, name: "u8")
    static let i16     = BasicType(kind: .i16,     flags: [.integer],            size: 2, name: "i16")
    static let u16     = BasicType(kind: .u16,     flags: [.integer, .unsigned], size: 2, name: "u16")
    static let i32     = BasicType(kind: .i32,     flags: [.integer],            size: 4, name: "i32")
    static let u32     = BasicType(kind: .u32,     flags: [.integer, .unsigned], size: 4, name: "u32")
    static let i64     = BasicType(kind: .i64,     flags: [.integer],            size: 8, name: "i64")
    static let u64     = BasicType(kind: .u64,     flags: [.integer, .unsigned], size: 8, name: "u64")
    static let int     = BasicType(kind: .int,     flags: [.integer],            size: -1, name: "int")
    static let uint    = BasicType(kind: .uint,    flags: [.integer, .unsigned], size: -1, name: "uint")

    static let f32     = BasicType(kind: .f32,     flags: [.float],              size: 4, name: "f32")
    static let f64     = BasicType(kind: .f64,     flags: [.float],              size: 8, name: "f64")

    static let rawptr  = BasicType(kind: .rawptr,  flags: [.pointer], size: -1, name: "rawptr")
    static let string  = BasicType(kind: .string,  flags: [.string],  size: -1, name: "string")

    static let unconstrBoolean = BasicType(kind: .unconstrained(.bool),    flags: [.boolean, .unconstrained], size: 0, name: "unconstrained bool")
    static let unconstrInteger = BasicType(kind: .unconstrained(.integer), flags: [.integer, .unconstrained], size: 0, name: "unconstrained integer")
    static let unconstrFloat   = BasicType(kind: .unconstrained(.float),   flags: [.float,   .unconstrained], size: 0, name: "unconstrained float")
    static let unconstrString  = BasicType(kind: .unconstrained(.string),  flags: [.string,  .unconstrained], size: 0, name: "unconstrained string")
    static let unconstrNil     = BasicType(kind: .unconstrained(.nil),     flags:           [.unconstrained], size: 0, name: "unconstrained nil")


    static let allBasicTypes: [BasicType] = [
        invalid,
        void,
        bool,
        i8, u8, i16, u16, i32, u32, i64, u64, f32, f64,
        int, uint,
        rawptr, string,
        unconstrBoolean, unconstrInteger, unconstrFloat, unconstrString, unconstrNil
    ]
}

// MARK: Static basic types
extension Type {

    static let invalid = Type(kind: .basic(.invalid), isInvalid: true)

    static let void    = Type(kind: .basic(.void))

    static let bool    = Type(kind: .basic(.bool))

    static let i8      = Type(kind: .basic(.i8))
    static let u8      = Type(kind: .basic(.u8))
    static let i16     = Type(kind: .basic(.i16))
    static let u16     = Type(kind: .basic(.u16))
    static let i32     = Type(kind: .basic(.i32))
    static let u32     = Type(kind: .basic(.u32))
    static let i64     = Type(kind: .basic(.i64))
    static let u64     = Type(kind: .basic(.u64))
    static let int     = Type(kind: .basic(.int))
    static let uint    = Type(kind: .basic(.uint))

    static let f32     = Type(kind: .basic(.f32))
    static let f64     = Type(kind: .basic(.f64))

    static let rawptr  = Type(kind: .basic(.rawptr))
    static let string  = Type(kind: .basic(.string))

    static let unconstrBoolean = Type(kind: .basic(.unconstrBoolean))
    static let unconstrInteger = Type(kind: .basic(.unconstrInteger))
    static let unconstrFloat   = Type(kind: .basic(.unconstrFloat))
    static let unconstrString  = Type(kind: .basic(.unconstrString))
    static let unconstrNil     = Type(kind: .basic(.unconstrNil))

    static let allBasicTypes: [Type] = [
        invalid,
        void,
        bool,
        i8, u8, i16, u16, i32, u32, i64, u64, f32, f64,
        int, uint,
        rawptr, string,
        unconstrBoolean, unconstrInteger, unconstrFloat, unconstrString, unconstrNil
    ]
}

extension ProcInfo: Equatable {

    static func == (lhs: ProcInfo, rhs: ProcInfo) -> Bool {
        //lhs.scope === rhs.scope &&
        return lhs.params == rhs.params &&
            lhs.returns == rhs.returns &&
            lhs.isVariadic == rhs.isVariadic &&
            isMemoryEquivalent(lhs.callingConvention, rhs.callingConvention)
    }
}
