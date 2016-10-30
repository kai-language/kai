
protocol Pass: ASTValidator {

  static var name: String { get }
  static func run(_ node: AST.Node) throws
}

extension Pass {

  static var name: String {
    let type = type(of: Self.self)
    return String(describing: type)
  }

  static var timing: String {
    return "\(name) took \(totalTime)s"
  }
}
