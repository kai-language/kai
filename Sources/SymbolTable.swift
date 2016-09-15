
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
