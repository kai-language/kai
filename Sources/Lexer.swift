
let whitespace = Set([space, tab, newline])

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  // splits the input stream into whitespace seperated strings
  mutating func tokenize(_ buffer: [UTF8.CodeUnit]) throws -> [Token] {

    guard !buffer.isEmpty else { return [] }

    var scanner: ByteScanner = try! ByteScanner(buffer)

    var tokens: [Token] = []

    var needsMatches: Stack<ByteString> = []

    var partial: ByteString = ""
    var outstandingRequiredMatches: Stack<ByteString> = []

    repeat {

      /// when we run out of byte return the tokens
      guard let char = scanner.peek() else {

        if !partial.isEmpty {
          guard let identifier = String(utf8: partial) else { throw Error.Reason.invalidUnicode }
          tokens.append(.identifier(identifier))
        }
        return tokens
      }

      let token = Token(partial)

      // TODO(vdka): HERE string support would go here with some fairly simple logic. (create stack of size _HERE_ put latest char into stack, compare stack value to _HERE_ value)

      if let terminator = Lexer.requiresMatch(partial) {
        outstandingRequiredMatches.push(terminator)
      } else if partial == outstandingRequiredMatches.peek() {
        outstandingRequiredMatches.pop()
      }

      // IMPORTANT: Do not do any early exit's before this point
      defer { scanner.pop() }

      guard token != .endOfStatement else {
        if !partial.isEmpty {
          guard let token = Token(partial) else { fatalError("Handle me") }
          tokens.append(token)
          partial.bytes.removeAll(keepingCapacity: true)
        }

        if tokens.last == .endOfStatement { continue }

        tokens.append(.endOfStatement)

        continue
      }

      if let token = token {

        tokens.append(token)
        continue
      }

      if char.isMember(of: whitespace) {

        guard !partial.bytes.isEmpty else { continue }
        guard let identifier = String(utf8: partial.bytes) else { throw Error.Reason.invalidUnicode }

        if Lexer.isLiteral(partial) != nil {
          tokens.append(.literal(identifier))
        } else {

          tokens.append(.identifier(identifier))
        }

         partial.bytes.removeAll(keepingCapacity: true)
        continue
      }

       partial.bytes.append(char)

    } while true
  }
}

extension Lexer {

  /// Tokens representing special syntax characters.
  enum Syntax: UTF8.CodeUnit {
    case openParentheses  = 0x28 // (
    case closeParentheses = 0x29 // )
    case openBrace        = 0x7b // {
    case closeBrace       = 0x7d // }
    case singleQuote      = 0x27 // '
    case doubleQuote      = 0x22 // "
    case atSymbol         = 0x40 // @
    case equals           = 0x3d // =
    case hash             = 0x23 // #
  }
}

extension Lexer {

  struct Error: Swift.Error {

    enum Reason: Swift.Error {
      case invalidUnicode
      case invalidLiteral
      case fileNotFound
      case endOfFile
    }
  }
}

extension UTF8.CodeUnit {

  func isMember(of set: Set<UTF8.CodeUnit>) -> Bool {
    return set.contains(self)
  }
}

