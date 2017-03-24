
let digits		= Array("1234567890".unicodeScalars)
let opChars     = Array("~!%^&+-*/=<>|?".unicodeScalars)
let identChars  = Array("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".unicodeScalars)
let whitespace  = Array(" \t\n".unicodeScalars)


typealias SourceRange = Range<SourceLocation>

struct SourceLocation {

    let file: String
    var line: UInt
    var column: UInt

    init(line: UInt, column: UInt, file: String? = nil) {
        self.line = line
        self.column = column
        self.file = file ?? "unknown"
    }

    static let zero = SourceLocation(line: 0, column: 0)
    static let unknown = SourceLocation(line: 0, column: 0)
}

extension SourceLocation: CustomStringConvertible {

    var description: String {
        let baseName = file.characters.split(separator: "/").map(String.init).last!
        return "\(baseName):\(line):\(column)"
    }
}

extension SourceLocation: Equatable, Comparable {

    public static func ==(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.file == rhs.file && lhs.line == rhs.line && lhs.column == rhs.column
    }

    /// - Precondition: both must be in the same file
    static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        if lhs.file != "unknown" && rhs.file != "unknown" {
            precondition(lhs.file == rhs.file)
        }

        return lhs.line < rhs.line
    }
}

struct Lexer {

	var scanner: FileScanner
	var buffer: [(kind: Token, location: SourceLocation)] = []

    var location: SourceLocation { return scanner.position }
	var lastLocation: SourceLocation
    var lastConsumedRange: SourceRange { return lastLocation ..< location }

	init(_ file: File) {

		self.scanner = FileScanner(file: file)
		self.lastLocation = scanner.position
	}

	mutating func peek(aheadBy n: Int = 0) throws -> (kind: Token, location: SourceLocation)? {
		if n < buffer.count { return buffer[n] }

		for _ in buffer.count...n {
			guard let token = try next() else { return nil }
			buffer.append(token)
		}
		return buffer.last
	}

	@discardableResult
	mutating func pop() throws -> (kind: Token, location: SourceLocation) {
		if buffer.isEmpty {
			let token = try next()!
			lastLocation = token.location
			return token
		}
		else {
			let token = buffer.removeFirst()
			lastLocation = token.location
			return token
		}
	}

	internal mutating func next() throws -> (kind: Token, location: SourceLocation)? {
		try skipWhitespace()

		guard let char = scanner.peek() else { return nil }

		let location = scanner.position

		switch char {
		case _ where identChars.contains(char):
			let symbol = consume(with: identChars + digits)

            if let keyword = Token.Keyword(rawValue: symbol) {
                return (.keyword(keyword), location)
            } else {
                return (.ident(symbol), location)
            }

		case _ where opChars.contains(char):
			let symbol = consume(with: opChars)
			if let keyword = Token.Keyword(rawValue: symbol) { return (.keyword(keyword), location) }
			else if symbol == "=" { return (.equals, location) }
			else { return (.operator(symbol), location) }

		// TODO(vdka): Correctly consume (and validate) number literals (real and integer)
		case _ where digits.contains(char):
			let number = consume(with: digits + ["."])

            if number.contains(".") {
                let dbl = Double(number)!
                return (.float(dbl), location)
            } else {
                let int = Int64(number)!
                return (.integer(int), location)
            }

		case "\"":
			scanner.pop()
            // FIXME(vdka): Currently doesn't handle escapes.
			let string = consume(upTo: "\"")
			guard case "\""? = scanner.peek() else { throw error(.unterminatedString) }
			scanner.pop()
			return (.string(string), location)

		case "(":
			scanner.pop()
			return (.lparen, location)

		case ")":
			scanner.pop()
			return (.rparen, location)

		case "[":
			scanner.pop()
			return (.lbrack, location)

		case "]":
			scanner.pop()
			return (.rbrack, location)

		case "{":
			scanner.pop()
			return (.lbrace, location)

		case "}":
			scanner.pop()
			return (.rbrace, location)

		case ":":
			scanner.pop()
			return (.colon, location)

        case ";":
            scanner.pop()
            return (.semicolon, location)

        case "\n":
            scanner.pop()
            return (.newline, location)

		case ",":
			scanner.pop()
			return (.comma, location)

		case ".":
			scanner.pop()
			return (.dot, location)

		case "#":
			scanner.pop()
			let identifier = consume(upTo: { !whitespace.contains($0) })
			guard let directive = Token.Directive(rawValue: identifier) else {
				throw error(.unknownDirective)
			}

			return (.directive(directive), location)

		default:
			let suspect = consume(upTo: whitespace.contains)

			throw error(.invalidToken(suspect))
		}
	}

	@discardableResult
	private mutating func consume(with chars: [UnicodeScalar]) -> String {

		var str: String = ""
		while let char = scanner.peek(), chars.contains(char) {
			scanner.pop()
			str.append(char)
		}

		return str
	}

	@discardableResult
	private mutating func consume(with chars: String) -> String {

		var str: String = ""
		while let char = scanner.peek(), chars.unicodeScalars.contains(char) {
			scanner.pop()
			str.append(char)
		}

		return str
	}

	@discardableResult
	private mutating func consume(upTo predicate: (UnicodeScalar) -> Bool) -> String {

		var str: String = ""
		while let char = scanner.peek(), predicate(char) {
			scanner.pop()
			str.append(char)
		}
		return str
	}

	@discardableResult
	private mutating func consume(upTo target: UnicodeScalar) -> String {

		var str: String = ""
		while let char = scanner.peek(), char != target {
			scanner.pop()
			str.append(char)
		}
		return str
	}

}

extension Lexer {

	fileprivate mutating func skipWhitespace() throws {
		while let char = scanner.peek() {

			switch char {
			case "/":
                switch scanner.peek(aheadBy: 1) {
                case "*"?:
                    try skipBlockComment()

                case "/"?:
                    skipLineComment()

                default:
                    return
                }
				try skipWhitespace() // skip consecutive comments or newlines after comments

			case _ where whitespace.contains(char):
				scanner.pop()

			default:
				return
			}
		}
	}

	private mutating func skipBlockComment() throws {
		assert(scanner.hasPrefix("/*"))

		scanner.pop(2)

		var depth: UInt = 1
		repeat {

			guard scanner.peek() != nil else {
				throw error(.unmatchedBlockComment)
			}

			if scanner.hasPrefix("*/") { depth -= 1 }
			else if scanner.hasPrefix("/*") { depth += 1 }

			scanner.pop()

			if depth == 0 { break }
		} while depth > 0
		scanner.pop()
	}

	private mutating func skipLineComment() {
		assert(scanner.hasPrefix("//"))

		while let char = scanner.peek(), char != "\n" { scanner.pop() }
	}
}

extension Lexer {

	func error(_ reason: Error.Reason, message: String? = nil) -> Swift.Error {
		return Error(message: reason.description, location: scanner.position, highlights: [])
	}

    struct Error: Swift.Error {

		var message: String?
		var location: SourceLocation
		var highlights: [SourceRange]

		enum Reason: Swift.Error, CustomStringConvertible {
			case unterminatedString
			case unknownDirective
			case unmatchedBlockComment
			case invalidToken(String)

			var description: String {

				switch self {
				case .unterminatedString: return "Unterminated string"
				case .unknownDirective: return "Unknown directive"
				case .unmatchedBlockComment: return "Unmatched block comment"
				case .invalidToken(let culprit): return "The token '\(culprit)' is unrecognized"
				}
			}
		}
	}
}

extension Lexer {

    enum Token {
        case directive(Directive)
        case keyword(Keyword)

        case ident(String)
        case `operator`(String)

        case string(String)
        case integer(Int64)
        case float(Double)

        case lparen
        case rparen
        case lbrace
        case rbrace
        case lbrack
        case rbrack

        case equals
        case colon
        case comma
        case dot

        /// Hard line terminator
        case semicolon

        /// Soft line terminator
        case newline

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

        case (.string(let l), .string(let r)):
            return l == r

        case (.integer(let l), .integer(let r)):
            return l == r

        case (.float(let l), .float(let r)):
            return l == r

        case (.semicolon, .semicolon),
             (.newline, .newline),
             (.lparen, .lparen),
             (.rparen, .rparen),
             (.lbrace, .lbrace),
             (.rbrace, .rbrace),
             (.lbrack, .lbrack),
             (.rbrack, .rbrack),
             (.equals, .equals),
             (.colon, .colon),
             (.comma, .comma),
             (.dot, .dot):
            return true
            
        default:
            return false
        }
    }
}
