

// TODO(vdka): Read this from the arguments
let file = FileReader(file: kaiRoot + "/Sources/main.swift")!

let tokens = try Tokenizer.tokenize(file: kaiRoot + "/Sources/main.swift")

print(tokens)
