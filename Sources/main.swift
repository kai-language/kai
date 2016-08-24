

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let bytes = Array(file)

var lexer = Lexer()

let tokens = try lexer.tokenize(bytes)

print(tokens)

for token in tokens {
  guard token != .endOfStatement else {
    print()
    continue
  }

  print(token, terminator: "")
}

