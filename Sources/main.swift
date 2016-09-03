

// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

let scanner = FileScanner(file: file)

var lexer = Lexer(scanner: scanner)


var previousLine: UInt = 0
var token = try lexer.getToken()
while token.type != .endOfStream {
  if previousLine != token.filePosition.line {
    print(token.filePosition.line)
  }
  if token.type == .unknown {
    if let value = token.value {
      print(value, terminator: "")
    } else {
      print("?", terminator: "")
    }
  } else if let value = token.value {
    print("\(token.type)(\(value))")
  } else {
    print(token.type, terminator: " ")
  }

  token = try lexer.getToken()

  previousLine = token.filePosition.line
}

/*
print("=== CAT ===")

for byte in bytes {
  print(UnicodeScalar(byte), terminator: "")
}

print("=== END ===")
*/
