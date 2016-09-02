
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

  mutating func parseString() throws -> ByteString {

    func parseUnicodeEscape() throws -> UTF16.CodeUnit {

      var codeUnit: UInt16 = 0
      for _ in 0..<4 {
        let c = scanner.pop()
        codeUnit <<= 4
        switch c {
        case numbers:
          codeUnit += UInt16(c - 48)
        case alphaNumericLower:
          codeUnit += UInt16(c - 87)
        case alphaNumericUpper:
          codeUnit += UInt16(c - 55)
        default:
          throw Error.Reason.invalidLiteral
        }
      }

      return codeUnit
    }

    func parseUnicodeScalar() throws -> UnicodeScalar {

      // For multi scalar Unicodes eg. flags
      var buffer: [UInt16] = []

      let codeUnit = try parseUnicodeEscape()
      buffer.append(codeUnit)

      if UTF16.isLeadSurrogate(codeUnit) {

        guard scanner.pop() == backslash && scanner.pop() == u else { throw Error.Reason.endOfFile }
        let trailingSurrogate = try parseUnicodeEscape()
        buffer.append(trailingSurrogate)
      }

      var gen = buffer.makeIterator()

      var utf = UTF16()

      switch utf.decode(&gen) {
      case .scalarValue(let scalar):
        return scalar

      case .emptyInput, .error:
        throw Error.Reason.invalidUnicode
      }
    }


    assert(scanner.peek() == quote)
    scanner.pop()

    var stringBuffer: [UTF8.CodeUnit] = []

    var escaped = false
    stringBuffer.removeAll(keepingCapacity: true)

    repeat {

      guard let codeUnit = scanner.peek() else { throw Error.Reason.invalidUnicode }
      scanner.pop()
      if codeUnit == backslash && !escaped {

        escaped = true
      } else if codeUnit == quote && !escaped {

        return ByteString(stringBuffer)
      } else if escaped {

        switch codeUnit {
        case r:
          stringBuffer.append(cr)

        case t:
          stringBuffer.append(tab)

        case n:
          stringBuffer.append(newline)

        case b:
          stringBuffer.append(backspace)

        case f:
          stringBuffer.append(formfeed)

        case quote:
          stringBuffer.append(quote)

        case slash:
          stringBuffer.append(slash)

        case backslash:
          stringBuffer.append(backslash)

        case u:
          let scalar = try parseUnicodeScalar()
          var bytes: [UTF8.CodeUnit] = []
          UTF8.encode(scalar, into: { bytes.append($0) })
          stringBuffer.append(contentsOf: bytes)

        default:
          throw Error.Reason.invalidUnicode
        }

        escaped = false

      } else {

        stringBuffer.append(codeUnit)
      }
    } while true
  }

  mutating func parseString(terminator: ByteString) throws -> Token {

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
        defer { partial.bytes.removeAll(keepingCapacity: true) }
        return .literal(partial)
      }
    } while true
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

      guard let char = scanner.peek() else { return tokens }
      switch char {

      case "\"":

        let stringLiteral = try parseString()

      case _ where whitespace.contains(char):

        print(partial)
        partial.bytes.removeAll(keepingCapacity: true)

      default:
        partial.bytes.append(scanner.pop())
        break
      }

      guard let token = Token(partial) else {
        guard terminators.contains(byte) else { continue }

        guard whitespace.contains(byte) else { continue }
        //scanner.pop()

        tokens.append(.identifier(partial))
        partial.bytes.removeAll(keepingCapacity: true)
        continue
      }
      partial.bytes.removeAll(keepingCapacity: true)

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
