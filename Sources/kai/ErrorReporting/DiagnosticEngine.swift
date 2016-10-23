
func report<Error: CompilerError>(_ error: Error) {

  let diagnostic = Diagnostic(.error, String(describing: error), location: error.location, highlights: error.highlights)

  print(diagnostic)
}

struct Diagnostic: Error {

  let message: String
  let severity: Severity
  let location: SourceLocation?
  var highlights: [SourceRange]
}

extension Diagnostic {

  init(_ severity: Severity, _ message: String? = nil, location: SourceLocation, highlights: [SourceRange] = []) {
    self.severity = severity
    self.message = message ?? "unknown"
    self.location = location
    self.highlights = highlights
  }
}

extension Diagnostic {

  mutating func highlight(_ range: SourceRange?) {
    guard let range = range else { return }
    highlights.append(range)
  }
}

extension Diagnostic: CustomStringConvertible {

  public var description: String {
    var description = ""
    if let location = location {
      description += "\(location.line):\(location.column): "
    }
    return description + "\(severity): \(message)"
  }
}
