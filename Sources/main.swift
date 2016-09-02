

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let scanner = FileScanner(file: file)

var lexer = Lexer(scanner: scanner)

print(#line)
let tokens = try! lexer.tokenize()
print(#line)

print()
print(tokens)
print()

for token in tokens {

  print(token)
  //print(token, terminator: "")
}

/*
print("=== CAT ===")

for byte in bytes {
  print(UnicodeScalar(byte), terminator: "")
}

print("=== END ===")
*/
