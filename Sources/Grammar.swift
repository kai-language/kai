

let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]",
    "+", "*", "-", "/"
  ]

let whitespace: Set<UTF8.CodeUnit> = [" ", "\t", "\n"]

var lexerGrammer: Trie<ByteString, Lexer.TokenType> = {

  var grammer = Trie<ByteString, Lexer.TokenType>(key: "_")

  // MARK: - Keywords

  grammer.insert("struct",       value: .structKeyword)
  grammer.insert("proc",         value: .procedureKeyword)
  grammer.insert("enum",         value: .enumKeyword)

  grammer.insert("import",       value: .importKeyword)
  grammer.insert("using",        value: .usingKeyword)
  grammer.insert("return",       value: .returnKeyword)
  grammer.insert("defer",        value: .deferKeyword)

  grammer.insert("if",           value: .ifKeyword)
  grammer.insert("else",         value: .elseKeyword)

  grammer.insert("switch",       value: .switchKeyword)
  grammer.insert("case",         value: .caseKeyword)
  grammer.insert("break",        value: .breakKeyword)
  grammer.insert("default",      value: .defaultKeyword)
  grammer.insert("fallthrough",  value: .fallthroughKeyword)

  grammer.insert("for",          value: .forKeyword)
  grammer.insert("continue",     value: .continueKeyword)

  grammer.insert("null",         value: .nullKeyword)
  grammer.insert("true",         value: .trueKeyword)
  grammer.insert("false",        value: .falseKeyword)

  grammer.insert("\n",           value: .newline)

  // MARK: - Non keyword

  grammer.insert("->",  value: .returnOperator)

  grammer.insert("//",  value: .lineComment)
  grammer.insert("/*",  value: .blockComment)

  grammer.insert("{",   value: .openBrace)
  grammer.insert("}",   value: .closeBrace)
  grammer.insert("[",   value: .openBracket)
  grammer.insert("]",   value: .closeBracket)
  grammer.insert("(",   value: .openParentheses)
  grammer.insert(")",   value: .closeParentheses)

  grammer.insert("+",   value: .plus)

  grammer.insert(":",   value: .colon)
  grammer.insert("=",   value: .assignment)
  grammer.insert("==",  value: .equality)

  grammer.insert(".",   value: .dot)
  grammer.insert(",",   value: .comma)

  grammer.insert(":=",  value: .declaration)
  grammer.insert("::",  value: .staticDeclaration)

  grammer.insert("\"",  value: .string)

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

    grammer.insert(numberStart,           value: .integer)
    grammer.insert(decimalStart,          value: .real)
    grammer.insert(negativeStart,         value: .real)
    grammer.insert(negativeDecimalStart,  value: .real)
  }

  return grammer
}()

extension Lexer {

  struct Token {

    var filePosition: FileScanner.Position

    var type: Lexer.TokenType
    var value: ByteString

    init(type: Lexer.TokenType, value: ByteString?, filePosition: FileScanner.Position) {

      self.filePosition = filePosition

      self.type = type
      self.value = type.defaultValue ?? value!
    }
  }
}

extension Lexer {

  enum TokenType {

    case unknown

    case lineComment
    case blockComment

    case newline

    case identifier

    case structKeyword
    case procedureKeyword
    case enumKeyword

    case importKeyword
    case usingKeyword
    case fnKeyword
    case returnKeyword
    case deferKeyword

    // ->
    case returnOperator

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
    case comma

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

      case .returnOperator:     return "->"

      case .solidus:            return "/"
      case .asterisk:           return "*"
      case .plus:               return "+"
      case .minus:              return "-"

      case .dot:                return "."
      case .comma:              return ","

      case .newline:            return "\n"

      case .structKeyword:      return "struct"
      case .procedureKeyword:   return "proc"
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
    if case .newline = type {

      return "\(type)('\("\\n")')"
    } else {
      return "\(type)('\(value)')"
    }
  }
}
