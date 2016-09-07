

let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]",
    "+", "*", "-", "/"
  ]

let whitespace: Set<UTF8.CodeUnit> = [" ", "\t", "\n"]

var grammer: Trie = {

  var grammer = Trie()

  // MARK: - Keywords

  grammer.insert("struct",       tokenType: .structKeyword)
  grammer.insert("enum",         tokenType: .enumKeyword)

  grammer.insert("import",       tokenType: .importKeyword)
  grammer.insert("using",        tokenType: .usingKeyword)
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


  // MARK: - Non keyword

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
  grammer.insert("=",   tokenType: .assignment)
  grammer.insert("==",  tokenType: .equality)

  grammer.insert(".",   tokenType: .dot)

  grammer.insert(":=",  tokenType: .declaration)
  grammer.insert("::",  tokenType: .staticDeclaration)

  grammer.insert("\"",  tokenType: .string)

  /*
    NOTE(vdka):
    Seems like parsing numbers using my Trie mechanism isn't _wonderful_
    Thinking maybe it could be fixed when I approach the issue of
    defining a set of acceptable _identifier_ & _operator_? starts
  */

  for n in Array<Byte>(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]) {
    let numberStart   = ByteString([n])
    let decimalStart  = ByteString([".", n])
    let negativeStart = ByteString(["-", n])
    let negativeDecimalStart = ByteString(["-", ".", n])

    grammer.insert(numberStart,           tokenType: .integer)
    grammer.insert(decimalStart,          tokenType: .real)
    grammer.insert(negativeStart,         tokenType: .real)
    grammer.insert(negativeDecimalStart,  tokenType: .real)
  }

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

    case declaration
    case staticDeclaration

    case dot

    case openBrace
    case closeBrace
    case openBracket
    case closeBracket
    case openParentheses
    case closeParentheses

    case doubleQuote
    case singleQuote

    case assignment
    case colon
    case hash

    case solidus
    case asterisk
    case plus
    case minus

    case equality

    case string
    case integer
    case real

    case endOfStream

    var defaultValue: ByteString? {

      switch self {
      case .openBrace:          return "{"
      case .closeBrace:         return "}"
      case .openBracket:        return "["
      case .closeBracket:       return "]"
      case .openParentheses:    return "("
      case .closeParentheses:   return ")"
      case .doubleQuote:        return "\""
      case .singleQuote:        return "'"
      case .assignment:         return "="
      case .colon:              return ":"
      case .hash:               return "#"
      case .equality:           return "=="

      case .solidus:            return "/"
      case .asterisk:           return "*"
      case .plus:               return "+"
      case .minus:              return "-"

      case .dot:                return "."

      case .structKeyword:      return "struct"
      case .enumKeyword:        return "enum"

      case .importKeyword:      return "import"
      case .usingKeyword:       return "using"
      case .returnKeyword:      return "return"
      case .deferKeyword:       return "defer"

      case .ifKeyword:          return "if"
      case .elseKeyword:        return "else"

      case .switchKeyword:      return "switch"
      case .caseKeyword:        return "case"
      case .breakKeyword:       return "break"
      case .defaultKeyword:     return "default"
      case .fallthroughKeyword: return "fallthrough"

      case .forKeyword:         return "for"
      case .continueKeyword:    return "continue"

      case .nullKeyword:        return "null"
      case .trueKeyword:        return "true"
      case .falseKeyword:       return "false"

      case .declaration:        return ":="
      case .staticDeclaration:  return "::"

      default:                  return nil
      }
    }

    var nextAction: ((inout Lexer) -> () throws -> Token)? {
      switch self {
      case .string:       return Lexer.parseString
      case .integer:      return Lexer.parseNumber
      case .real:         return Lexer.parseNumber
      case .lineComment:  return Lexer.parseLineComment
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
