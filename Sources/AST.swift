
class AST {

  typealias Node = AST

  weak var parent: Node?
  var children: [Node]

  var filePosition: FileScanner.Position?

  var kind: Kind

  init(_ kind: Kind, parent: Node? = nil, children: [Node] = [], filePosition: FileScanner.Position? = nil) {
    self.kind = kind
    self.parent = parent
    self.children = children
    self.filePosition = filePosition
    for child in children {

      child.parent = self
    }
  }
}

extension AST {

  enum Kind {
    case unknown

    case emptyFile(name: ByteString)
    case file(name: ByteString)
    case declaration(Declaration)

    case integerLiteral(ByteString)
    case stringLiteral(ByteString)
  }
}

class Symbol {
  let name: ByteString
  var kind: Kind

  /// - Note: Multiple `Type`s are possible when the kind is a procedure
  var types: [KaiType]? = []

  init(_ name: ByteString, kind: Kind, type: KaiType? = nil) {
    self.name = name
    self.kind = kind

    self.types = []
    if let type = type {
      self.types?.append(type)
    }
  }

  enum Kind {
    case type
    case variable
    case procedure
  }
}

class SymbolTable {

  weak var parent: SymbolTable? = nil
  var table = Trie<ByteString, Symbol>()
}

extension SymbolTable {

  func insert(_ symbol: Symbol) {
    table.insert(symbol, forKeyPath: symbol.name)
  }

  func lookup(_ name: ByteString) -> Symbol? {
    var currentScope = self

    repeat {
      guard let symbol = currentScope.table.contains(name) else {
         guard let parent = parent else { return nil }

         currentScope = parent
         continue
      }

      return symbol
    } while true
  }
}

enum KaiType {
  case integer(ByteString)
  case string(ByteString)
  case other(identifier: ByteString)
}

struct Declaration {
  var symbol: Symbol
  var flags: Flag

  struct Flag: OptionSet {
    let rawValue: UInt8
    init(rawValue: UInt8) { self.rawValue = rawValue }

    static let compileTime = 0b0001
  }
}
