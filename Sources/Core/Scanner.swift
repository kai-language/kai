
import Foundation

fileprivate let byteOrderMark = UnicodeScalar(0xFEFF)

struct Scanner {

    typealias Triplet = (pos: Pos, tok: Token, lit: String)
    typealias ErrorHandler = (String, Pos) -> Void

    var file: SourceFile
    var data: Data

    var ch: Unicode.Scalar?
    var offset: Int = 0
    var readOffset: Int = 0
    var lineOffset: Int = 0
    var insertSemi = false

    var errorHandler: ErrorHandler?

    init(file: SourceFile, errorHandler: ErrorHandler?) {
        self.file = file
        self.data = file.handle.readDataToEndOfFile()
        self.ch = " "
        self.errorHandler = errorHandler

        next()
        if ch == byteOrderMark {
            next()
        }
    }

    mutating func next() {
        let inOffset = offset
        let inReadOffset = readOffset
        defer {
            if offset != 0 && ch != nil {
                assert(offset < readOffset)
                assert(readOffset - 1 == inReadOffset)
                assert(offset - 1 == inOffset)
            }
        }
        guard readOffset < data.count else {
            offset = data.endIndex
            if ch == "\n" {
                lineOffset = offset
                file.addLine(offset: offset)
            }
            ch = nil // eof
            return
        }

        offset = readOffset
        if ch == "\n" {
            file.linesOfSource += insertSemi ? 1 : 0
            lineOffset = offset
            file.addLine(offset: offset)
        }

        var decoder = UTF8()
        var iterator = data[offset...].makeIterator()
        var scalar: UnicodeScalar
        switch decoder.decode(&iterator) {
        case .scalarValue(let v):
            scalar = v
            if v == byteOrderMark {
                reportError("Illegal byte order mark", at: offset)
            } else if ch == "\0" {
                reportError("Illegal character NUL", at: offset)
            }
        case .emptyInput:
            fatalError("Empty is handled prior")
        case .error:
            reportError("illegal UTF8 encoding", at: offset)
            scalar = Unicode.Scalar(UInt32(0xFFFD))!
        }

        readOffset += unicodeScalarByteLength(data[offset])
        ch = scalar
    }

    mutating func scanComment() -> String {
        // initial "/" already consumed; s.ch == "/" || s.ch == "*"
        let start = offset - 1

        if ch == "/" {
            //-style comment
            next()
            while ch != "\n" && ch != nil {
                next()
            }
        } else {
            /*-style comment */
            next()
            while let ch = ch {
                next()
                if ch == "*" && self.ch == "/" {
                    next()
                    break
                }
            }
            if ch == nil {
                reportError("Comment not terminated", at: start)
            }
        }

        return String(bytes: data[start..<offset], encoding: .utf8)!
    }

    mutating func findLineEnd() -> Bool {
        let originalState = (ch, offset, readOffset)
        defer {
            (ch, offset, readOffset) = originalState
        }

        while ch == "/" || ch == "*" {
            if ch == "/" {
                //-style comments always end lines
                return true
            }
            /*-style comment: look for newline */
            next()
            while let ch = ch {
                if ch == "\n" {
                    return true
                }
                next()
                if ch == "*" && self.ch == "/" {
                    next()
                    break
                }
            }
            skipWhitespace() // s.insertSemi is set
            if ch == "\n" || ch == nil {
                return true
            }
            if ch != "/" {
                // non-comment token
                return false
            }
            next()
        }

        return false
    }

    mutating func scanIdentifier() -> String {
        let start = offset
        while let ch = ch, isLetter(ch) || isDigit(ch) {
            next()
        }
        return String(bytes: data[start..<offset], encoding: .utf8)!
    }

    mutating func scanMantissa(_ base: Int) {
        while let ch = ch {
            if ch != "_" && digitVal(ch) >= base {
                break
            }
            next()
        }
    }

    mutating func scanNumber(seenDecimalPoint: Bool) -> (Token, String) {
        var start = offset
        var tok = Token.int
        var mustBeInteger = false

        if seenDecimalPoint {
            start -= 1
            tok = Token.float
            scanMantissa(10)
        }

        // significant
        if ch == "0" && !seenDecimalPoint {
            // int or float
            next()

            switch ch {
            case "x"?:
                next()
                scanMantissa(16)
                mustBeInteger = true
                if offset - start <= 2 {
                    reportError("Illegal hexadecimal number", at: start)
                }
            case "b"?:
                next()
                scanMantissa(2)
                mustBeInteger = true
                if offset - start <= 2 {
                    reportError("Illegal hexadecimal number", at: start)
                }
            default:
                scanMantissa(10)
            }
        }

        if !seenDecimalPoint && !mustBeInteger {
            scanMantissa(10)
        }

        // fraction
        if ch == "." && !mustBeInteger && !seenDecimalPoint {
            tok = .float
            next()
            scanMantissa(10)
        }

        // exponent
        if ch == "e" || ch == "E" && !mustBeInteger {
            tok = .float
            let exponent = offset
            next()
            if ch == "-" || ch == "+" {
                next()
            }
            if let ch = ch, digitVal(ch) < 10 {
                scanMantissa(10)
            } else {
                reportError("Illegal floating-point exponent", at: exponent)
            }
        }

        let lit = String(bytes: data[start..<offset], encoding: .utf8)!
        return (tok, lit)
    }

    @discardableResult
    mutating func scanEscape(quote: Unicode.Scalar) -> Bool {
        let start = offset

        var n = 0
        var base, max: UInt32
        switch ch {
        case "a"?, "b"?, "f"?, "n"?, "r"?, "t"?, "v"?, "\\"?, quote?:
            next()
            return true
        case "x"?:
            next()
            (n, base, max) = (4, 16, 255)
        case "u"?:
            next()
            (n, base, max) = (4, 16, 0x0010FFFF) // Unicode max rune.
        case "U"?:
            next()
            (n, base, max) = (8, 16, 0x0010FFFF) // Unicode max rune.
        default:
            let msg = ch == nil ? "Escape sequence not terminated" : "Unknown escape sequence"
            reportError(msg, at: start)
            return false
        }

        var x: UInt32 = 0
        while n > 0 {
            guard let ch = ch else {
                reportError("Escape sequence not terminated", at: offset)
                return false
            }
            let digit = UInt32(digitVal(ch))
            if digit >= base {
                reportError("Illegal character \(ch) in escape sequence", at: offset)
                return false
            }
            x *= base + digit
            next()
            n -= 1
        }

        if x > max || 0xD800 <= x && x < 0xE000 {
            reportError("Escape sequence is an invalid Unicode code point", at: start)
            return false
        }

        return true
    }

    mutating func scanString() -> String {
        let start = offset

        while true {
            guard let ch = ch else {
                reportError("String literal not terminated", at: start)
                break
            }
            next()
            if ch == "\"" {
                break
            }
            if ch == "\\" {
                scanEscape(quote: "\"")
            }
        }

        return String(bytes: data[start..<offset - 1], encoding: .utf8)!
    }

    mutating func skipWhitespace() {
        while ch == " " || ch == "\t" || ch == "\n" && !insertSemi || ch == "\r" {
            next()
        }
    }

    mutating func lookupKeyword(_ identifier: String) -> Token? {
        switch identifier {
        case "goto":
            return .goto
        case "break":
            return .break
        case "continue":
            return .continue
        case "fallthrough":
            return .fallthrough
        case "return":
            return .return
        case "if":
            return .if
        case "for":
            return .for
        case "else":
            return .else
        case "defer":
            return .defer
        case "switch":
            return .switch
        case "case":
            return .case
        case "fn":
            return .fn
        case "union":
            return .union
        case "enum":
            return .enum
        case "struct":
            return .struct
        default:
            return nil
        }
    }

    mutating func switch2(_ tok0: Token, _ tok1: Token) -> Token {
        if ch == "=" {
            next()
            return tok1
        }
        return tok0
    }

    mutating func switch3(_ tok0: Token, _ tok1: Token, ch2: Unicode.Scalar, tok2: Token) -> Token {
        if ch == "=" {
            next()
            return tok1
        }
        if ch == ch2 {
            next()
            return tok2
        }
        return tok0
    }

    mutating func switch4(_ tok0: Token, _ tok1: Token, _ ch2: Unicode.Scalar, _ tok2: Token, _ tok3: Token) -> Token {
        if ch == "=" {
            next()
            return tok1
        }
        if ch == ch2 {
            next()
            if ch == "=" {
                next()
                return tok3
            }
            return tok2
        }
        return tok0
    }

    mutating func scan() -> (Pos, Token, String) {
        skipWhitespace()

        var insertSemi = false
        guard let ch = ch else {
            if self.insertSemi {
                self.insertSemi = false
                return (offset, .semicolon, "\n")
            }
            return (offset, .eof, "")
        }

        let start = offset
        var tok: Token
        var lit: String = ""

        switch ch {
        case _ where isLetter(ch):
            lit = scanIdentifier()
            if lit.count > 1 { // all keywords are longer than 1 character
                tok = lookupKeyword(lit) ?? .ident
                switch tok {
                case .ident, .break, .continue, .fallthrough, .return:
                    insertSemi = true
                default:
                    break
                }
            } else {
                insertSemi = true
                tok = .ident
            }
        case "0"..."9":
            insertSemi = true
            (tok, lit) = scanNumber(seenDecimalPoint: false)
        default:
            next() // always make progress
            switch ch {
            case "\n":
                // we only reach here is self.insertSemi was
                // set in the first place and exited early
                // from self.skipWhitespace()
                self.insertSemi = false // newline consumed
                return (start, .semicolon, "\n")
            case "\"":
                insertSemi = true
                tok = .string
                lit = scanString()
            case ":":
                tok = .colon
            case ".":
                if let ch = self.ch, "0" <= ch && ch <= "9" {
                    insertSemi = true
                    (tok, lit) = scanNumber(seenDecimalPoint: true)
                } else if self.ch == "." {
                    next()
                    tok = .ellipsis
                } else {
                    tok = .period
                }
            case "?":
                tok = .question
            case ",":
                tok = .comma
            case ";":
                tok = .semicolon
            case "(":
                tok = .lparen
            case ")":
                insertSemi = true
                tok = .rparen
            case "[":
                tok = .lbrack
            case "]":
                insertSemi = true
                tok = .rbrack
            case "{":
                tok = .lbrace
            case "}":
                insertSemi = true
                tok = .rbrace
            case "+":
                tok = switch2(.add, .assignAdd)
            case "-":
                tok = switch3(.sub, .assignSub, ch2: ">", tok2: .retArrow)
            case "*":
                tok = switch2(.mul, .assignMul)
            case "#":
                tok = .directive
                lit = scanIdentifier()
            case "/":
                if self.ch == "/" || self.ch == "*" {
                    // comment
                    if self.insertSemi && findLineEnd() {
                        // reset position to the beginning of the comment
                        self.ch = "/"
                        self.offset = start
                        self.readOffset = start + 1
                        self.insertSemi = false // newline consumed
                        return (start, .semicolon, "\n")
                    }
                    tok = .comment
                    lit = scanComment()
                } else {
                    tok = switch2(.quo, .assignQuo)
                }
            case "%":
                tok = switch2(.rem, .assignRem)
            case "^":
                tok = switch2(.xor, .assignXor)
            case "<":
                tok = switch4(.lss, .leq, "<", .shl, .assignShl)
            case "=":
                tok = switch2(.assign, .eql)
            case "!":
                tok = switch2(.not, .neq)
            case "&":
                tok = switch3(.and, .assignAnd, ch2: "&", tok2: .land)
            case "|":
                tok = switch3(.or, .assignOr, ch2: "|", tok2: .lor)
            default:
                // next reports unexpected Byte Order Marks - don't repeat
                if ch != byteOrderMark {
                    reportError("Illegal character \(ch)", at: start)
                }
                insertSemi = self.insertSemi // preserve insertSemi
                tok = .illegal
                lit = String(ch)
            }
        }
        self.insertSemi = insertSemi

        return (start, tok, lit)
    }
}

extension Scanner {

    func reportError(_ message: String, at offset: Int, file: StaticString = #file, line: UInt = #line) {
        let pos = self.file.pos(offset: offset)
        errorHandler?(message, pos)
    }
}

func isLetter(_ ch: Unicode.Scalar) -> Bool {
    return "a" <= ch && ch <= "z" || "A" <= ch && ch <= "Z" || ch == "_" // TODO Allow unicode letters
}

func isDigit(_ ch: Unicode.Scalar) -> Bool {
    return "0" <= ch && ch <= "9"
}

func digitVal(_ ch: Unicode.Scalar) -> Int {

    if "0" <= ch && ch <= "9" {
        return Int(ch.value - UnicodeScalar("0")!.value)
    }
    if "a" <= ch && ch <= "f" {
        return Int(ch.value - UnicodeScalar("a")!.value)
    }
    if "A" <= ch && ch <= "F" {
        return Int(ch.value - UnicodeScalar("A")!.value)
    }
    return 16 // larger than is permitted
}
