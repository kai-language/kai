
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

print(ast.pretty())
print()

let ir = IRBuilder.getIR(for: ast)

print(ir)

// print(parserGrammer.pretty())
