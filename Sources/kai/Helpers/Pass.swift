
protocol Pass {

  static var name: String { get }
  static func run(_ node: AST.Node) throws
}

extension Pass {

  static var name: String {
    let type = type(of: Self.self)
    return String(describing: type)
  }

  static func runTimed(_ node: AST.Node) throws {
    let (_, time) = try measure {
      try run(node)
    }

    print("\(Self.name) pass took \(time)s")
  }
}
