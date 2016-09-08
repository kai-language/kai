
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

let scanner = FileScanner(file: file)

var lexer = Lexer(scanner: scanner)


var tokens: [Lexer.Token] = []
var token: Lexer.Token
repeat {
  token = try lexer.getToken()

  print("\(file.name)(\(token.filePosition.line):\(token.filePosition.column)): \(token)")

  tokens.append(token)
} while token.type != .endOfStream

print("Done Lexing")
print()

var parser = Parser(tokens)

let ast = try parser.parse()
print()

let ir = IRBuilder.getIR(for: ast)

print(ir)

print(ast)
