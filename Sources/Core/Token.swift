
enum Token: UInt8 {
    case illegal
    case eof
    case comment

    case ident
    case directive

    // literals
    case int
    case float
    case string

    case add     // +
    case sub     // -
    case mul     // *
    case quo     // /
    case rem     // %

    case and     // &
    case or      // |
    case xor     // ^
    case shl     // <<
    case shr     // >>

    case assignAdd  // +=
    case assignSub  // -=
    case assignMul  // *=
    case assignQuo  // /=
    case assignRem  // %=

    case assignAnd  // &=
    case assignOr   // |=
    case assignXor  // ^=
    case assignShl  // <<=
    case assignShr  // >>=

    case land       // &&
    case lor        // ||

    case lss        // <
    case gtr        // >
    case not        // !

    case eql        // ==
    case neq        // !=
    case leq        // <=
    case geq        // >=

    case assign     // =
    case ellipsis   // ..
    case dollar     // $
    case question   // ?
    case retArrow   // ->

    case lparen     // (
    case lbrack     // [
    case lbrace     // {
    case rparen     // )
    case rbrack     // ]
    case rbrace     // }

    case comma      // ,
    case period     // .
    case colon      // :
    case semicolon  // ;

    // Keywords
    case goto
    case `break`
    case `continue`
    case `fallthrough`

    case `return`

    case `if`
    case `for`
    case `else`
    case `defer`

    case `switch`
    case `case`

    case fn
    case union
    case `enum`
    case `struct`

    case `nil`
}

struct Pos: Comparable {
    var fileno: UInt32
    var offset: UInt32

    static func + (lhs: Pos, rhs: Int) -> Pos {
        var pos = lhs
        pos.offset += UInt32(rhs)
        return pos
    }

    static func - (lhs: Pos, rhs: Int) -> Pos {
        var pos = lhs
        pos.offset -= UInt32(rhs)
        return pos
    }

    static func ==(lhs: Pos, rhs: Pos) -> Bool {
        return lhs.offset == rhs.offset && rhs.fileno == rhs.fileno
    }

    static func <(lhs: Pos, rhs: Pos) -> Bool {
        return lhs.offset < rhs.offset && rhs.fileno == rhs.fileno
    }

    static let filenomask: UInt64 = 0xFF00000000000000
    static let offsetmask: UInt64 = ~filenomask
}
//typealias Pos = UInt
let noPos: Pos = Pos(fileno: 0, offset: 0)

struct Position {

    /// filename
    var filename: String
    /// offset, starting at 0
    var offset: UInt32
    /// line number, starting at 1
    var line: UInt32
    /// column number, starting at 1 (byte count)
    var column: UInt32
}

extension Token: CustomStringConvertible {
    var description: String {
        switch self {
        case .illegal:   return "<illegal>"
        case .eof:       return "<EOF>"
        case .comment:   return "<comment>"
        case .ident:     return "<ident>"
        case .directive: return "<directive>"
        case .int:       return "<int>"
        case .float:     return "<float>"
        case .string:    return "<string>"
        case .add:       return "+"
        case .sub:       return "-"
        case .mul:       return "*"
        case .quo:       return "/"
        case .rem:       return "%"
        case .and:       return "&"
        case .or:        return "|"
        case .xor:       return "^"
        case .shl:       return "<<"
        case .shr:       return ">>"
        case .land:      return "&&"
        case .lor:       return "||"
        case .lss:       return "<"
        case .gtr:       return ">"
        case .not:       return "!"
        case .eql:       return "=="
        case .neq:       return "!="
        case .leq:       return "<="
        case .geq:       return ">="
        case .assign:    return "="
        case .ellipsis:  return ".."
        case .dollar:    return "$"
        case .question:  return "?"
        case .retArrow:  return "->"
        case .lparen:    return "("
        case .lbrack:    return "["
        case .lbrace:    return "{"
        case .rparen:    return ")"
        case .rbrack:    return "]"
        case .rbrace:    return "}"
        case .comma:     return ","
        case .period:    return "."
        case .colon:     return ":"
        case .semicolon: return ";"
        case .goto:      return "goto"
        case .break:     return "break"
        case .continue:  return "continue"
        case .fallthrough: return "fallthrough"
        case .return:    return "return"
        case .if:        return "if"
        case .for:       return "for"
        case .else:      return "else"
        case .defer:     return "defer"
        case .switch:    return "switch"
        case .case:      return "case"
        case .fn:        return "fn"
        case .union:     return "union"
        case .enum:      return "enum"
        case .struct:    return "struct"
        case .nil:       return "nil"
        case .assignAdd: fallthrough
        case .assignSub: fallthrough
        case .assignMul: fallthrough
        case .assignQuo: fallthrough
        case .assignRem: fallthrough
        case .assignAnd: fallthrough
        case .assignOr:  fallthrough
        case .assignXor: fallthrough
        case .assignShl: fallthrough
        case .assignShr:
            return Token(rawValue: self.rawValue - 10)!.description + "="
        }
    }
}

extension Position: CustomStringConvertible {

    var description: String {
        let filename = basename(path: self.filename)
        return "\(filename):\(line):\(column)"
    }
}


