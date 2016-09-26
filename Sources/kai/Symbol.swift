
class Symbol {
  let name: ByteString
  var kind: Kind
  let position: FileScanner.Position
  var flags: Flag

  /// - Note: Multiple `Type`s are possible when the kind is a procedure
  var types: [KaiType] = []

  init(_ name: ByteString, kind: Kind, filePosition: FileScanner.Position, type: KaiType? = nil, flags: Flag = []) {
    self.name = name
    self.kind = kind
    self.position = filePosition
    self.types = []
    self.flags = flags

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

  struct Flag: OptionSet {
    let rawValue: UInt8
    init(rawValue: UInt8) { self.rawValue = rawValue }

    static let compileTime = Flag(rawValue: 0b0001)
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
