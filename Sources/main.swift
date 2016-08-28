

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let bytes = Array(file)

var scanner = try! ByteScanner(bytes)

var lexer = Lexer(scanner: scanner)

let tokens = try lexer.tokenize()

print()
print(tokens)
print()

for token in tokens {
  guard token != .endOfStatement else {
    print()
    continue
  }

  print(token)
  //print(token, terminator: "")
}

print("=== CAT ===")

for byte in bytes {
  print(UnicodeScalar(byte), terminator: "")
}

print("=== END ===")

