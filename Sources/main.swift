
guard let fileName = CommandLine.arguments.dropFirst().first else {
  fatalError("Please provide a file")
}

let kaiRoot = "/" + #file.characters
  .split(separator: "/")
  .dropLast(2)
  .map(String.init)
  .joined(separator: "/")

// print(grammer)

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/" + fileName)!

let tokens = try Lexer.tokenize(file)

var parser = Parser(tokens)

let ast = try parser.parse()

let ir = IRBuilder.getIR(for: ast)

print(ir)

var parserGrammer: Trie<[Lexer.TokenType], (inout Parser) -> () throws -> AST.Node> = {
    // var nextAction: ((inout Lexer) -> () throws -> Token)? {

  var parserGrammer: Trie<[Lexer.TokenType], (inout Parser) -> () throws -> AST.Node> = Trie(key: .unknown)

  parserGrammer.insert(Parser.parseImport,    forKeyPath: [.importKeyword, .string])
  parserGrammer.insert(Parser.parseStruct,    forKeyPath: [.identifier, .staticDeclaration, .structKeyword])
  parserGrammer.insert(Parser.parseProcedure, forKeyPath: [.identifier, .staticDeclaration, .openParentheses])
  parserGrammer.insert(Parser.parseEnum,      forKeyPath: [.identifier, .staticDeclaration, .enumKeyword])

  return parserGrammer
}()

print(parserGrammer.pretty())
