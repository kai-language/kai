

enum Severity: String { case error, warning, note }

protocol CompilerError: Swift.Error, CustomStringConvertible {

  var severity: Severity { get }
  var message: String? { get }
  var location: SourceLocation { get }
  var highlights: [SourceRange] { get set }
}

extension CompilerError {

  var description: String {

    // (?<file>.+):(?<line>\\d+):(?<col>\\d+):\\s(?<type>warning|error):\\s(?<message>.+)
    return "\(location): error: \(message ?? "Something went wrong")"
  }
}
