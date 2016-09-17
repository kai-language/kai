

let terminators: Set<UTF8.CodeUnit> =
  [
    " ", "\t", "\n",
    ".", ",", ":", "=", "(", ")", "{", "}", "[", "]",
    "+", "*", "-", "/"
  ]

let identifierHeads: [Byte] = {

  var heads: [Byte] = []

  heads.append("_")
  heads.append(contentsOf: "a"..."z")
  heads.append(contentsOf: "A"..."Z")

  return heads
}()

let identifierBody: [Byte] = {

  var body: [Byte] = []

  body.append(contentsOf: identifierHeads)

  body.append(contentsOf: "0"..."9")

  return body
}()

let operatorBody: [Byte] = {

  var body: [Byte] = []

  body.append("/")
  body.append("=")
  body.append("-")
  body.append("+")
  body.append("*")
  body.append("%")
  body.append("<")
  body.append(">")
  body.append("&")
  body.append("|")
  body.append("^")
  body.append("~")
  body.append("!")
  body.append("?")

  return body
}()

let whitespace: Set<UTF8.CodeUnit> = [" ", "\t", "\n"]

var lexerGrammar: Trie<ByteString, Lexer.TokenType> = {

  var grammar = Trie<ByteString, Lexer.TokenType>(key: "_")

  // MARK: - Keywords

  grammar.insert("struct",       value: .structKeyword)
  grammar.insert("enum",         value: .enumKeyword)

  grammar.insert("inline",       value: .inlineKeyword)

  grammar.insert("import",       value: .importKeyword)
  grammar.insert("using",        value: .usingKeyword)
  grammar.insert("return",       value: .returnKeyword)
  grammar.insert("defer",        value: .deferKeyword)

  grammar.insert("infix",        value: .infixKeyword)
  grammar.insert("prefix",       value: .prefixKeyword)
  grammar.insert("postfix",      value: .postfixKeyword)

  grammar.insert("if",           value: .ifKeyword)
  grammar.insert("else",         value: .elseKeyword)

  grammar.insert("switch",       value: .switchKeyword)
  grammar.insert("case",         value: .caseKeyword)
  grammar.insert("break",        value: .breakKeyword)
  grammar.insert("default",      value: .defaultKeyword)
  grammar.insert("fallthrough",  value: .fallthroughKeyword)

  grammar.insert("for",          value: .forKeyword)
  grammar.insert("continue",     value: .continueKeyword)

  grammar.insert("null",         value: .nullKeyword)
  grammar.insert("true",         value: .trueKeyword)
  grammar.insert("false",        value: .falseKeyword)

  grammar.insert("\n",           value: .newline)

  // MARK: - Non keyword

  //grammar.insert("->",  value: .returnOperator)

  grammar.insert("//",  value: .lineComment)
  grammar.insert("/*",  value: .blockComment)

  grammar.insert("{",   value: .openBrace)
  grammar.insert("}",   value: .closeBrace)
  grammar.insert("[",   value: .openBracket)
  grammar.insert("]",   value: .closeBracket)
  grammar.insert("(",   value: .openParentheses)
  grammar.insert(")",   value: .closeParentheses)

  grammar.insert(":",   value: .colon)
  grammar.insert("=",   value: .assign)
  grammar.insert("==",  value: .equality)

  grammar.insert(".",   value: .dot)
  grammar.insert(",",   value: .comma)

  grammar.insert(":=",  value: .declaration)
  grammar.insert("::",  value: .staticDeclaration)

  grammar.insert("\"",  value: .string)

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

    grammar.insert(numberStart,           value: .integer)
    grammar.insert(decimalStart,          value: .real)
    grammar.insert(negativeStart,         value: .real)
    grammar.insert(negativeDecimalStart,  value: .real)
  }

  return grammar
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
    case operatorIdentitifer

    case structKeyword
    case enumKeyword

    case inlineKeyword

    case importKeyword
    case usingKeyword
    case returnKeyword
    case deferKeyword

    case infixKeyword
    case prefixKeyword
    case postfixKeyword

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

    case assign
    case colon
    case hash

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

      case .colon:              return ":"
      case .hash:               return "#"

      case .declaration:        return ":="
      case .staticDeclaration:  return "::"
      case .assign:             return "="

      case .returnOperator:     return "->"

      case .dot:                return "."
      case .comma:              return ","

      case .newline:            return "\n"

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

    switch type {
    case .blockComment: return "\(type)('/* ... */')"
    case .lineComment: return "\(type)('// ...')"
    case .newline: return "\(type)('\\n')"
    default: return "\(type)('\(value)')"
    }
  }
}
