
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

    // Operators
    case address // &

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
    case ellipsis   // ...
    case dollar     // $
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
}

typealias Pos = Int
let noPos: Pos = 0

struct Position {

    /// filename
    var filename: String
    /// offset, starting at 0
    var offset: Int
    /// line number, starting at 1
    var line: Int
    /// column number, starting at 1 (byte count)
    var column: Int
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
        case .address:   return "&"
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
        case .assign:    return "="
        case .ellipsis:  return "..."
        case .dollar:    return "$"
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

        default:
            return String(describing: self)
        }
    }
}

extension Position: CustomStringConvertible {

    var description: String {
        let filename = basename(path: self.filename)
        return "\(filename):\(line):\(column)"
    }
}


