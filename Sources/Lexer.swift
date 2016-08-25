
let terminatorList: Set<ByteString> = Set(" \t\n.,:=(){}[]".utf8.map { ByteString([$0]) })

let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var tokens: [Token] = []
  var beginHereString = false

  func requiresMatch(_ string: ByteString) -> ByteString? {

    switch string {
    case "{":  return "}"
    case "(":  return ")"
    case "'":  return "'"
    case "\"": return "\""

    case _ where beginHereString: return string

    default: return nil
    }
  }

  // splits the input stream into whitespace seperated strings
  mutating func tokenize(_ buffer: [UTF8.CodeUnit]) throws -> [Token] {

    guard !buffer.isEmpty else { return [] }

    var scanner = try! ByteScanner(buffer)

    var needsMatches: Stack<ByteString> = []

    var partial: ByteString = ""
    var outstandingRequiredMatches: Stack<ByteString> = []

    repeat {

      /// when we run out of byte return the tokens
      guard let byte = scanner.peek() else {

        if !partial.isEmpty {
          guard let identifier = String(utf8: partial) else { throw Error.Reason.invalidUnicode }
          tokens.append(.identifier(identifier))
        }
        return tokens
      }

      partial.bytes.append(byte)

      scanner.pop()

      // if we don't get a token, what would we possibly want to do?
      //  Seriously is there something? I don't normally write Lexers.
      guard let token = Token(partial) else { continue }
      tokens.append(token)

      partial.bytes.removeAll(keepingCapacity: true)

      if case .hereString(let terminator) = token {
        assert(terminator.hasSuffix("`") && terminator.hasPrefix("`"))

        repeat {

          let byte = try scanner.attemptPop()

          partial.bytes.append(byte)

          if partial.hasSuffix(ByteString(terminator.utf8)) {
            partial.bytes.removeLast(terminator.utf8.count)
            tokens.append(.literal(String(utf8: partial)!))
            tokens.append(.hereString(terminator))
            break
          }
        } while true
      }

      // TODO(vdka): HERE string support would go here with some fairly simple logic. (create stack of size _HERE_ put latest char into stack, compare stack value to _HERE_ value)
      // Decision, HERE strings will be of the form `HERE`some literal complex stupid string`HERE`


      // IMPORTANT: Do not do any early exit's before this point

      // DISCUSS(vdka): clean up multiple newlines into a single thing. Or strip them all together.
      /*
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
      */

      // If our partial requires a Match we should take note
      if let terminator = requiresMatch(partial) {

        if terminator == partial {
          // we have a here string. Until we match the terminator just fill
          //  the parial buffer and at the end we have a StringLiteralToken
          partial = ""

          repeat {

            if partial.hasSuffix(terminator) {
              partial.bytes.removeLast(terminator.count)
            }
          } while true

        }
        outstandingRequiredMatches.push(terminator)
      } else if partial == outstandingRequiredMatches.peek() {
        outstandingRequiredMatches.pop()
      }


      //if char.isMember(of: whitespace) {

      //  guard !partial.bytes.isEmpty else { continue }
      //  guard let identifier = String(utf8: partial.bytes) else { throw Error.Reason.invalidUnicode }

      //  if Lexer.isLiteral(partial) != nil {
      //    tokens.append(.literal(identifier))
      //  } else {
      //    tokens.append(.identifier(identifier))
      //  }

      //   partial.bytes.removeAll(keepingCapacity: true)
      //  continue
      //}

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

