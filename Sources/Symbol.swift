
class Symbol {
  let name: ByteString
  var kind: Kind

  /// - Note: Multiple `Type`s are possible when the kind is a procedure
  var types: [KaiType] = []

  init(_ name: ByteString, kind: Kind, type: KaiType? = nil) {
    self.name = name
    self.kind = kind
    self.types = []

    if let type = type {
      self.types.append(type)
    }
  }

  enum Kind {
    case type
    case variable
    case procedure
    case `operator`
  }
}

extension Symbol: CustomStringConvertible {

  var description: String {
    let typeDescription: String
    switch types.first {
    case .some(_) where types.count > 1:
      typeDescription = "overloaded"

    case let type?:
      typeDescription = String(describing: type)

    case nil:
      typeDescription = "unknown"
    }
    return "\(kind) \(typeDescription) '\(name)'"
  }
}
