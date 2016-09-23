
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

    case string
    case integer
    case real

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

    case colon
    case dot
    case comma

    case op

    case assign

    case openBrace
    case closeBrace
    case openBracket
    case closeBracket
    case openParentheses
    case closeParentheses

    case doubleQuote
    case singleQuote

    case hash

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
