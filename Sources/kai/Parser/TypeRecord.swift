
import LLVM


/// TypeRecord represents a Type that a variable can take.
/// - Note: This is a reference type.
class TypeRecord {

    var name: String?

    var kind: Kind

    var source: Source

    var node: AST.Node?

    var llvm: IRType?

    init(name: String? = nil, kind: Kind, source: Source = .native, node: AST.Node? = nil, llvm: IRType? = nil) {
        self.name = name
        self.kind = kind
        self.source = source
        self.node = node
        self.llvm = llvm
    }
}

extension TypeRecord {

    enum Kind {

        case invalid

        /// The basic types in most languages. Ints, Floats, string
        case basic(BasicType)

        case pointer(TypeRecord)
        case array(TypeRecord, count: Int)
        case dynArray(TypeRecord)

        /// This is the result of type(TypeName)
        case record(TypeRecord)

        /// This may be nil if the alias is for an unresolved type (Foreign types)
        case alias(TypeRecord)

        case proc(ProcInfo)
        case `struct`(StructInfo)
        case `enum`(EnumInfo)
    }

    enum Source {
        case native
        case llvm
        case extern(ByteString)
    }
}

extension TypeRecord {

    var isTypeValid: Bool {
        if case .invalid = self.kind { return false }
        return true
    }

    var isTypeBasic: Bool {
        if case .basic(_) = self.kind { return true }
        return false
    }

    var isTypePointer: Bool {
        if case .pointer(_) = self.kind { return true }
        return false
    }

    var isTypeArray: Bool {
        if case .array(_) = self.kind { return true }
        return false
    }

    var isTypeDynamicArray: Bool {
        if case .dynArray(_) = self.kind { return true }
        return false
    }

    var isTypeRecord: Bool {
        if case .record(_) = self.kind { return true }
        return false
    }

    var isTypeAlias: Bool {
        if case .alias(_) = self.kind { return true }
        return false
    }

    var isTypeProc: Bool {
        if case .proc(_) = self.kind { return true }
        return false
    }

    var isTypeStruct: Bool {
        if case .struct(_) = self.kind { return true }
        return false
    }

    var isTypeEnum: Bool {
        if case .enum(_) = self.kind { return true }
        return false
    }
}

extension TypeRecord {

    struct ProcInfo {
        var scope: AST.Node?
        var labels: [(callsite: ByteString?, binding: ByteString)]?
        var params: [TypeRecord]
        var returns: [TypeRecord]
        var isVariadic: Bool
        var callingConvention: CallingConvention

        init(
            scope: AST.Node? = nil,
            labels: [(callsite: ByteString?, binding: ByteString)]?,
            params: [TypeRecord],
            returns: [TypeRecord],
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

    struct StructInfo {
        var fieldCount: Int
        var fieldTypes: [TypeRecord]
    }

    struct EnumInfo {
        var caseCount: Int
        var cases: [String]
        var baseType: TypeRecord
    }
}

struct BasicType {
    var kind: Kind
    var flags: Flag
    var size: Int64
    var name: String

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
    static let f32     = BasicType(kind: .f32,     flags: [.float],              size: 4, name: "f32")
    static let f64     = BasicType(kind: .f64,     flags: [.float],              size: 8, name: "f64")
    static let int     = BasicType(kind: .int,     flags: [.integer],            size: -1, name: "int")
    static let uint    = BasicType(kind: .uint,    flags: [.integer, .unsigned], size: -1, name: "uint")

    static let rawptr  = BasicType(kind: .rawptr,  flags: [.pointer], size: -1, name: "rawptr")
    static let string  = BasicType(kind: .string,  flags: [.string],  size: -1, name: "string")

    static let unconstrBoolean = BasicType(kind: .unconstrained(.bool),    flags: [.boolean, .unconstrained], size: 0, name: "unconstrained bool")
    static let unconstrInteger = BasicType(kind: .unconstrained(.integer), flags: [.integer, .unconstrained], size: 0, name: "unconstrained integer")
    static let unconstrFloat   = BasicType(kind: .unconstrained(.float),   flags: [.float,   .unconstrained], size: 0, name: "unconstrained float")
    static let unconstrString  = BasicType(kind: .unconstrained(.string),  flags: [.string,  .unconstrained], size: 0, name: "unconstrained string")
    static let unconstrNil     = BasicType(kind: .unconstrained(.nil),     flags:           [.unconstrained], size: 0, name: "unconstrained nil")
}

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

    static let allBasicTypes: [TypeRecord] = [
        invalid,
        void,
        bool,
        i8, u8, i16, u16, i32, u32, i64, u64, f32, f64,
        int, uint,
        rawptr, string,
        unconstrBoolean, unconstrInteger, unconstrFloat, unconstrString, unconstrNil
    ]

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

extension BasicType {

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

extension BasicType: Equatable {

    static func == (lhs: BasicType, rhs: BasicType) -> Bool {
        return isMemoryEquivalent(lhs.kind, rhs.kind)
    }
}

extension TypeRecord.ProcInfo: Equatable {

    static func == (lhs: TypeRecord.ProcInfo, rhs: TypeRecord.ProcInfo) -> Bool {
        return
            lhs.scope === rhs.scope &&
            lhs.params == rhs.params &&
            lhs.returns == rhs.returns &&
            lhs.isVariadic == rhs.isVariadic &&
            isMemoryEquivalent(lhs.callingConvention, rhs.callingConvention)
    }
}

extension TypeRecord.StructInfo: Equatable {

    static func == (lhs: TypeRecord.StructInfo, rhs: TypeRecord.StructInfo) -> Bool {
        return
            lhs.fieldCount == rhs.fieldCount &&
            lhs.fieldTypes == rhs.fieldTypes
    }
}

extension TypeRecord.EnumInfo: Equatable {

    static func == (lhs: TypeRecord.EnumInfo, rhs: TypeRecord.EnumInfo) -> Bool {
        return
            lhs.caseCount == rhs.caseCount &&
            lhs.cases == rhs.cases &&
            lhs.baseType == rhs.baseType
    }
}

extension TypeRecord: Equatable {

    static func == (lhs: TypeRecord, rhs: TypeRecord) -> Bool {
        guard lhs.node === rhs.node else { return false }
        switch (lhs.kind, rhs.kind) {
        case (.invalid, .invalid):
            return true

        case let (.basic(lhs), .basic(rhs)):
            return lhs == rhs

        case let (.pointer(lhs), .pointer(rhs)):
            return lhs == rhs

        case let (.array(lhs, count: lCount), .array(rhs, count: rCount)):
            return lCount == rCount && lhs == rhs

        case let (.dynArray(lhs), .dynArray(rhs)):
            return lhs == rhs

        case let (.record(lhs), .record(rhs)):
            return lhs == rhs

        case let (.alias(lhs), .alias(rhs)):
            return lhs == rhs

        case let (.proc(lhs), .proc(rhs)):
            return lhs == rhs

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
