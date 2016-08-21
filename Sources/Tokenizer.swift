
extension FileReader {

  enum Error: Swift.Error {
    case fileNotFound
  }
}

struct Tokenizer {


  static func tokenize<T: Sequence>(reader: T) -> [String]
    where T.Iterator.Element == UTF8.CodeUnit
  {
    reader
      .split(maxSplits: .max, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
      .
  }
}
