
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

do {

  let tokens = try Lexer.tokenize(file)

  var lastLine: UInt = 0
  for token in tokens {
    if token.filePosition.line == lastLine {
      print(token, terminator: " ")
    } else {
      lastLine += 1
      print(token)
    }
  }

  print("Done lexing\n")

  //var parser = Parser(tokens)

  //let ast = try parser.parse()

  let ast = try TrieParser.parse(tokens)

  print(ast.pretty())
  print()

  let ir = IRBuilder.getIR(for: ast)

  print(ir)
} catch {
  print("error: \(error)")
}

// print(parserGrammer.pretty())
