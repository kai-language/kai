
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
