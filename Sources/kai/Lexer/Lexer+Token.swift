
extension Lexer {

    // TODO(vdka): Change into `Token.Kind` add to `Token` a location and an optional kind
    enum Token {
        case directive(Directive)
        case keyword(Keyword)
        case literal(String)
        case ident(String)
        case `operator`(String)

        case lparen
        case rparen
        case lbrace
        case rbrace
        case lbrack
        case rbrack

        case equals
        case scolon
        case colon
        case comma
        case dot


        enum Keyword: String {
            case `struct`
            case `enum`

            case `if`
            case `else`
            case `return`

            case `defer`

            case `for`
            case `break`
            case `continue`

            case type
            case alias

            case returnArrow = "->"
        }

        enum Directive: String {
            case file
            case line
            case `import`
            case foreign = "foreign"
            case foreignLLVM = "foreign(LLVM)"
        }
    }
}

extension Lexer.Token: Equatable {

    static func == (lhs: Lexer.Token, rhs: Lexer.Token) -> Bool {
        switch (lhs, rhs) {
        case (.directive(let l), .directive(let r)):
            return l == r

        case (.keyword(let l), .keyword(let r)):
            return l == r

        case (.ident(let l), .ident(let r)):
            return l == r

        case (.operator(let l), .operator(let r)):
            return l == r

        case (.literal(let l), .literal(let r)):
            return l == r

        case (.lparen, .lparen),
             (.rparen, .rparen),
             (.lbrace, .lbrace),
             (.rbrace, .rbrace),
             (.lbrack, .lbrack),
             (.rbrack, .rbrack),
             (.equals, .equals),
             (.scolon, .scolon),
             (.colon, .colon),
             (.comma, .comma),
             (.dot, .dot):
            return true

        default:
            return false
        }
    }
}
