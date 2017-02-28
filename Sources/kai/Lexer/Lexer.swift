
let digits			= Array<Byte>("1234567890".utf8)
let opChars			= Array<Byte>("~!%^&+-*/=<>|?".utf8)
let identChars	= Array<Byte>("_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)
let whitespace	= Array<Byte>(" \t\n".utf8)


struct Lexer {

	var scanner: FileScanner
	var buffer: [(kind: Token, location: SourceLocation)] = []

	var lastLocation: SourceLocation

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
			let symbol = consume(with: identChars + digits).string
			if let keyword = Token.Keyword(rawValue: symbol) { return (.keyword(keyword), location) }
			else if symbol == "_" { return (.underscore, location) }
			else { return (.ident(symbol), location) }

		case _ where opChars.contains(char):
			let symbol = consume(with: opChars).string
			if let keyword = Token.Keyword(rawValue: symbol) { return (.keyword(keyword), location) }
			else if symbol == "=" { return (.equals, location) }
			else { return (.operator(symbol), location) }

		// TODO(vdka): Correctly consume (and validate) number literals (real and integer)
		case _ where digits.contains(char):
			let number = consume(with: digits).string
			return (.literal(number), location)

		case "\"":
			scanner.pop()
			let string = consume(upTo: "\"").string
			guard case "\""? = scanner.peek() else { throw error(.unterminatedString) }
			scanner.pop()
			return (.literal(string), location)

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

		case ",":
			scanner.pop()
			return (.comma, location)

		case ".":
			scanner.pop()
			return (.dot, location)

		case "#":
			scanner.pop()
			let identifier = consume(upTo: { !whitespace.contains($0) }).string
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
	private mutating func consume(with chars: [Byte]) -> ByteString {

		var str: ByteString = ""
		while let char = scanner.peek(), chars.contains(char) {
			scanner.pop()
			str.append(char)
		}

		return str
	}

	@discardableResult
	private mutating func consume(with chars: ByteString) -> ByteString {

		var str: ByteString = ""
		while let char = scanner.peek(), chars.bytes.contains(char) {
			scanner.pop()
			str.append(char)
		}

		return str
	}

	@discardableResult
	private mutating func consume(upTo predicate: (Byte) -> Bool) -> ByteString {

		var str: ByteString = ""
		while let char = scanner.peek(), predicate(char) {
			scanner.pop()
			str.append(char)
		}
		return str
	}

	@discardableResult
	private mutating func consume(upTo target: Byte) -> ByteString {

		var str: ByteString = ""
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
				if scanner.peek(aheadBy: 1) == "*" { try skipBlockComment() }
				else if scanner.peek(aheadBy: 1) == "/" { skipLineComment() }
				try skipWhitespace()
				return

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
		return Error(severity: .error, message: reason.description, location: scanner.position, highlights: [])
	}

	struct Error: CompilerError {
		var severity: Severity

		var message: String?
		var location: SourceLocation
		var highlights: [SourceRange]

		enum Reason: Swift.Error, CustomStringConvertible {
			case unterminatedString
			case unknownDirective
			case unmatchedBlockComment
			case invalidToken(ByteString)

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
