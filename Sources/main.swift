

// TODO(vdka): Read this from the arguments
let file = FileReader(file: kaiRoot + "/Sources/main.swift")!

let lines =
  file
    .lazy
    .split(separator: newline)
    .flatMap(String.init)
    .filter { !$0.hasPrefix("//") }

let tokens =
  lines
    .lazy
    .map {
      $0.characters.split(separator: " ", maxSplits: .max, omittingEmptySubsequences: true).map(String.init)
    }


for token in tokens {
  print(token)
}
