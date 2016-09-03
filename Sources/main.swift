

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let scanner = FileScanner(file: file)

var tokenizer = Tokenizer(scanner: scanner)

//let tokens = try! tokenizer.tokenize()

print()
//print(tokens)
try print(tokenizer.getToken())
print()

var token = try tokenizer.getToken()
while token.type != .endOfStream {
  print(token)
  token = try tokenizer.getToken()
}

/*
print("=== CAT ===")

for byte in bytes {
  print(UnicodeScalar(byte), terminator: "")
}

print("=== END ===")
*/
