
let kaiRoot = "/" + #file.characters
  .split(separator: "/")
  .dropLast(2)
  .map(String.init)
  .joined(separator: "/")

// print(grammer)

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let scanner = FileScanner(file: file)

var lexer = Lexer(scanner: scanner)

var token = try lexer.getToken()

while token.type != .endOfStream {

  print("\(file.name)(\(token.filePosition.line):\(token.filePosition.column))", terminator: ": ")

  print(token)

  token = try lexer.getToken()
}
