
class Symbol {
  let name: ByteString
  var kind: Kind
  // TODO(vdka): Needs to be per overload
  var source: Source
  let position: FileScanner.Position
  var flags: Flag

  /// - Note: Multiple `Type`s are possible when the kind is a procedure
  var types: [KaiType] = []

  init(_ name: ByteString, kind: Kind, filePosition: FileScanner.Position, type: KaiType? = nil, flags: Flag = []) {
    self.name = name
    self.kind = kind
    self.source = .native
    self.position = filePosition
    self.types = []
    self.flags = flags

    if let type = type {
      self.types.append(type)
    }
  }

  // NOTE(vdka): I am still not sure Kind is required
  enum Kind {
    case type
    case variable
    case procedure
    case `operator`
  }

  enum Source {
    case native
    case llvm
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
    return "\(source == .native ? "" : String(describing: source)) \(kind) '\(name)' \(typeDescription)"
  }
}
