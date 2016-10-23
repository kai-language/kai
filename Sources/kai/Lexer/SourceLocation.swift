
typealias SourceRange = Range<SourceLocation>

struct SourceLocation {

  let file: String
  var line: UInt
  var column: UInt

  init(line: UInt, column: UInt, file: String? = nil) {
    self.line = line
    self.column = column
    self.file = file ?? "unknown"
  }

  static let zero = SourceLocation(line: 0, column: 0)
  static let unknown = SourceLocation(line: 0, column: 0)
}

extension SourceLocation: CustomStringConvertible {

  var description: String {
    let baseName = file.characters.split(separator: "/").map(String.init).last!
    return "\(baseName):\(line):\(column)"
  }
}

extension SourceLocation: Equatable, Comparable {

  public static func ==(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    return lhs.file == rhs.file && lhs.line == rhs.line && lhs.column == rhs.column
  }

  /// - Precondition: both must be in the same file
  static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
    precondition(lhs.file == rhs.file)

    return lhs.line < rhs.line
  }
}
