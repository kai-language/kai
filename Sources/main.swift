
//extension Lexer {
//
//  mutating func lex() -> [] {
//
//    var tokens: [String] = []
//
//    while let tokenBytes = scanner.consume(to: whitespace.contains) {
//      guard !tokenBytes.isEmpty else { continue }
//      guard let string = String(utf8: tokenBytes) else { fatalError("Invalid Unicode") }
//      tokens.append(string)
//    }
//
//    return tokens
//  }
//}


// TODO(vdka): Read this from the arguments
let file = File(path: kaiRoot + "/sample.kai")!

var lexer = Lexer(file: file)

let tokens = lexer.tokenize()

print(tokens)
