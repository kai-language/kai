
let kaiRoot = "/" + #file.characters.split(separator: "/").dropLast(2).map(String.init).joined(separator: "/")

struct Lexer {

  var scanner: ByteScanner
  var partial: ByteString = ""

  init(scanner: ByteScanner) {

    self.scanner = scanner
  }

  func requiresMatch(_ string: ByteString) -> ByteString? {

    switch string {
    case "{":  return "}"
    case "(":  return ")"
    case "'":  return "'"
    case "\"": return "\""

    default: return nil
    }
  }

  // splits the input stream into whitespace seperated strings
  mutating func tokenize() throws -> [Token] {

    var tokens: [Token] = []

    //var needsMatches: Stack<ByteString> = []

    var outstandingRequiredMatches: Stack<ByteString> = []

    repeat {

      /// when we run out of byte return the tokens
      guard let byte = scanner.peek() else {

        if !partial.isEmpty {
          tokens.append(.identifier(partial))
        }
        return tokens
      }

      partial.bytes.append(byte)


      guard let token = Token(partial) else {
        guard terminators.contains(byte) else { continue }

        guard whitespace.contains(byte) else { continue }
        scanner.pop()

        tokens.append(.identifier(partial))
        partial.bytes.removeAll(keepingCapacity: true)
        continue
      }
      scanner.pop()
      partial.bytes.removeAll(keepingCapacity: true)

      switch token {
      case .hereString(let terminator):
        assert(terminator.hasSuffix("`") && terminator.hasPrefix("`"))

        print()
        print()
        print()
        print()
        print("TERMINATOR: \(terminator)")
        print()
        print()
        print()
        print()

        repeat {

          let byte: UTF8.CodeUnit
          do {
            byte = try scanner.attemptPop()
          } catch {
            throw Error.Reason.unmatchedToken(terminator)
          }

          partial.bytes.append(byte)

          if partial.hasSuffix(terminator) {
            partial.bytes.removeLast(terminator.count)
            tokens.append(.literal(partial))
            partial.bytes.removeAll(keepingCapacity: true)
            break
          }
        } while true

      default:
        tokens.append(token)
      }

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

    } while true
  }
}

extension Lexer {

  struct Error: Swift.Error {

    enum Reason: Swift.Error {
      case unmatchedToken(ByteString)
      case invalidUnicode
      case invalidLiteral
      case fileNotFound
      case endOfFile
    }
  }
}

