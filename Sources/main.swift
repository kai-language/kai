

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let scanner = FileScanner(file: file)

var tokenizer = Tokenizer(scanner: scanner)


var previousLine: UInt = 0
var token = try tokenizer.getToken()
while token.type != .endOfStream {
  if previousLine != token.filePosition.line {
    print(token.filePosition.line)
  }
  if token.type == .unknown {
    print("?", terminator: " ")
  } else {
    print(token.type, terminator: " ")
  }

  token = try tokenizer.getToken()

  previousLine = token.filePosition.line
}

/*
print("=== CAT ===")

for byte in bytes {
  print(UnicodeScalar(byte), terminator: "")
}

print("=== END ===")
*/
