

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let bytes = Array(file)

var lexer = Lexer()

let tokens = try lexer.tokenize(bytes)

print(tokens)

