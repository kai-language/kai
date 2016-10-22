
protocol ASTValidator {

  static var name: String { get }
  static var totalTime: Double { get set }
  static func validate(_ node: AST.Node) throws
}

struct SemanticError: CompilerError {

  var reason: Reason
  var message: String?
  var location: SourceLocation

  init(_ reason: Reason, message: String? = nil, location: SourceLocation) {
    self.reason = reason
    self.message = message ?? "Something went wrong."
    self.location = location
  }

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

  static var name: String { return String(describing: Self.self) }

  static func validate(_ node: AST.Node, options: ASTValidatorOption) throws {

    if options.contains(.timed) {

      let (_, time) = try measure {
        try validate(node)
      }

      Self.totalTime += time
    } else {
      try validate(node)
    }
  }
}
