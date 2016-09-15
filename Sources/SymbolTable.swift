
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

extension SymbolTable: CustomStringConvertible {

  var description: String {

    var str = ""

    if let parent = parent {
      str.append(parent.description)
      str.append("=======")
    }

    table.forEach {
      str.append(String(describing: $0))
      str.append("\n")
    }

    return str
  }
}
