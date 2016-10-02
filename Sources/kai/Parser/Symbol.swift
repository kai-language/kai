
class Symbol {
  let name: ByteString
  var source: Source
  let position: FileScanner.Position
  var flags: Flag

  var type: KaiType?

  /// - Precondition: The current symbol table must align with where this symbol is defined.
  /// - Returns: An array of other overload's for type that are overloadable, nil otherwise
  var overloads: [Symbol]? {
    switch type {
    case .procedure(labels: _, arguments: _, returnType: _)?: 
      return SymbolTable.current.table.filter({ $0.name == name })

    default: 
      return nil
    }
  }

  init(_ name: ByteString, filePosition: FileScanner.Position, type: KaiType? = nil, flags: Flag = []) {
    self.name = name
    self.source = .native
    self.position = filePosition
    self.type = type
    self.flags = flags
  }

  enum Source {
    case native
    case llvm(ByteString)
  }

  struct Flag: OptionSet {
    let rawValue: UInt8
    init(rawValue: UInt8) { self.rawValue = rawValue }

    static let compileTime = Flag(rawValue: 0b0001)
  }
}

extension Symbol: CustomStringConvertible {

  var description: String {
    return "\(name): \(type) (\(source))"
  }
}
