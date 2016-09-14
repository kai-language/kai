
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

struct Symbol {
  var name: ByteString
  var kind: Kind
  var type: KaiType?

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

  static var global = SymbolTable()

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
  var name: ByteString
  var type: KaiType
  var flags: Flag

  struct Flag: OptionSet {
    let rawValue: UInt8
    init(rawValue: UInt8) { self.rawValue = rawValue }

    static let compileTime = 0b0001
  }
}
