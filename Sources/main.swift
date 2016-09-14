
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

  var lexer = Lexer(file: file)

  let ast = try Parser.parse(lexer)

  print(ast.pretty())

} catch {
  print("error: \(error)")
}

// print(parserGrammer.pretty())
