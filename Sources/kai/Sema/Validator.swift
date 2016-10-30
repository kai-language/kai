
protocol ASTValidator {

  static var name: String { get }
  static var totalTime: Double { get set }
  static func run(_ node: AST) throws
}

struct SemanticError: CompilerError {

  var severity: Severity
  var message: String?
  var location: SourceLocation
  var highlights: [SourceRange]

  enum Reason: Swift.Error {
    case badrvalue
    case badlvalue
  }
}

struct ASTValidatorOption: OptionSet {

  let rawValue: UInt

  init(rawValue: UInt) { self.rawValue = rawValue }

  static let timed = ASTValidatorOption(rawValue: 0b0001)
}

extension ASTValidator {

  static func error(_ reason: SemanticError.Reason, location: SourceLocation) -> SemanticError {
    return SemanticError(severity: .error, message: String(describing: reason), location: location, highlights: [])
  }

  static func error(_ reason: SemanticError.Reason, at node: AST.Node) -> SemanticError {
    return SemanticError(severity: .error, message: String(describing: reason), location: node.location!, highlights: [])
  }

  static var name: String { return String(describing: Self.self) }

  static func run(_ node: AST.Node, options: ASTValidatorOption) throws {

    if options.contains(.timed) {

      let (_, time) = try measure {
        try run(node)
      }

      Self.totalTime += time
    } else {
      try run(node)
    }
  }
}
