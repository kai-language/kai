

let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]",
    "+", "*", "-", "/"
  ]

let whitespace: Set<UTF8.CodeUnit> = [" ", "\t", "\n"]

var grammer: Trie = {

  var grammer = Trie()

  grammer.insert("struct",       tokenType: .structKeyword)
  grammer.insert("enum",         tokenType: .enumKeyword)

  grammer.insert("static",       tokenType: .staticKeyword)

  grammer.insert("import",       tokenType: .importKeyword)
  grammer.insert("using",        tokenType: .usingKeyword)
  grammer.insert("fn",           tokenType: .fnKeyword)
  grammer.insert("return",       tokenType: .returnKeyword)
  grammer.insert("defer",        tokenType: .deferKeyword)

  grammer.insert("if",           tokenType: .ifKeyword)
  grammer.insert("else",         tokenType: .elseKeyword)

  grammer.insert("switch",       tokenType: .switchKeyword)
  grammer.insert("case",         tokenType: .caseKeyword)
  grammer.insert("break",        tokenType: .breakKeyword)
  grammer.insert("default",      tokenType: .defaultKeyword)
  grammer.insert("fallthrough",  tokenType: .fallthroughKeyword)

  grammer.insert("for",          tokenType: .forKeyword)
  grammer.insert("continue",     tokenType: .continueKeyword)

  grammer.insert("null",         tokenType: .nullKeyword)
  grammer.insert("true",         tokenType: .trueKeyword)
  grammer.insert("false",        tokenType: .falseKeyword)

  grammer.insert("//",           tokenType: .lineComment)
  grammer.insert("/*",           tokenType: .blockComment)

  grammer.insert("{",   tokenType: .openBrace)
  grammer.insert("}",   tokenType: .closeBrace)
  grammer.insert("[",   tokenType: .openBracket)
  grammer.insert("]",   tokenType: .closeBracket)
  grammer.insert("(",   tokenType: .openParentheses)
  grammer.insert(")",   tokenType: .closeParentheses)

  grammer.insert("+",   tokenType: .plus)

  grammer.insert(":",   tokenType: .colon)
  grammer.insert("=",   tokenType: .equals)
  grammer.insert("==",   tokenType: .equals)
  grammer.insert(":=",  tokenType: .typeInferedDeclaration)

  grammer.insert("\"",  tokenType: .string)

  grammer.insert(contentsOf: "0"..."9", tokenType: .number)

  return grammer
}()

extension Lexer {

  struct Token {

    var filePosition: FileScanner.Position

    var type: Lexer.TokenType
    var value: ByteString?

    init(type: Lexer.TokenType, value: ByteString?, filePosition: FileScanner.Position) {

      self.filePosition = filePosition

      self.type = type
      self.value = type.defaultValue ?? value

      // set the column position to the start of the token
     self.filePosition.column -= numericCast(value?.count ?? 0)
    }
  }
}

extension Lexer {

  enum TokenType {

    case unknown

    case lineComment
    case blockComment

    case identifier

    case structKeyword
    case enumKeyword

    case staticKeyword

    case importKeyword
    case usingKeyword
    case fnKeyword
    case returnKeyword
    case deferKeyword

    case ifKeyword
    case elseKeyword

    case switchKeyword
    case caseKeyword
    case breakKeyword
    case defaultKeyword
    case fallthroughKeyword

    case forKeyword
    case continueKeyword

    case nullKeyword
    case trueKeyword
    case falseKeyword


    case typeInferedDeclaration

    case openBrace
    case closeBrace
    case openBracket
    case closeBracket
    case openParentheses
    case closeParentheses

    case doubleQuote
    case singleQuote

    case solidus
    case asterisk
    case plus
    case minus

    case equals
    case colon
    case hash

    case string
    case number

    case endOfStream

    var defaultValue: ByteString? {

      switch self {
      case .openBrace:        return "{"
      case .closeBrace:       return "}"
      case .openBracket:      return "["
      case .closeBracket:     return "]"
      case .openParentheses:  return "("
      case .closeParentheses: return ")"
      case .doubleQuote:      return "\""
      case .singleQuote:      return "'"
      case .equals:           return "="
      case .colon:            return ":"
      case .hash:             return "#"

      case .solidus:          return "/"
      case .asterisk:         return "*"
      case .plus:             return "+"
      case .minus:            return "-"

      case .typeInferedDeclaration: return ":="

      default:                return nil
      }
    }

    var nextAction: ((inout Lexer) -> () throws -> Token)? {
      switch self {
      case .string: return Lexer.parseString
      case .number: return Lexer.parseNumber
      case .lineComment: return Lexer.parseLineComment
      case .blockComment: return Lexer.parseBlockComment

      default: return nil
      }
    }
  }
}

extension Lexer.Token: CustomStringConvertible {

  var description: String {
    return "\(type)(\(value ?? ""))"
  }
}
