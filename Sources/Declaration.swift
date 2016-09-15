
struct Declaration {
  var symbol: Symbol
  var flags: Flag

  init(_ symbol: Symbol, flags: Flag = []) {
    self.flags = flags
    self.symbol = symbol
  }

  struct Flag: OptionSet {
    let rawValue: UInt8
    init(rawValue: UInt8) { self.rawValue = rawValue }

    static let compileTime = Flag(rawValue: 0b0001)
  }
}

extension Declaration: CustomStringConvertible {

  var description: String {
    return flags.isEmpty ? symbol.description : "compileTime \(symbol)"
  }
}
