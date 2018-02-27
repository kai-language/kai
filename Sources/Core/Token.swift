
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
    case bnot       // ~

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
    case cast
    case bitcast
    case autocast

    case using

    case goto
    case `break`
    case `continue`
    case `fallthrough`

    case `return`

    case `if`
    case `for`
    case `else`
    case `defer`
    case `in`

    case `switch`
    case `case`

    case fn
    case union
    case `enum`
    case `struct`

    case `nil`
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
        case .bnot:      return "~"
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
        case .cast:      return "cast"
        case .bitcast:   return "bitcast"
        case .autocast:  return "autocast"
        case .using:     return "using"
        case .goto:      return "goto"
        case .break:     return "break"
        case .continue:  return "continue"
        case .fallthrough: return "fallthrough"
        case .return:    return "return"
        case .if:        return "if"
        case .for:       return "for"
        case .else:      return "else"
        case .defer:     return "defer"
        case .in:        return "in"
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
