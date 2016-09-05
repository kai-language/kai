

// NOTE(vdka): A Trie can be used to parse by keeping track of the trie node we are up to.

struct Trie {

  var root: Node = Node("_")

  var count: Int = 0
  var nodeCount: Int = 0

}

extension Trie {

  mutating func insert(_ value: ByteString, tokenType: Lexer.TokenType) {

    var currentNode = root

    for (index, byte) in value.enumerated() {

      guard let nextNode = currentNode[byte] else {

        let nextNode = Node(byte)
        nodeCount += 1

        currentNode[byte] = nextNode

        currentNode = nextNode

        if index == value.lastIndex {
          nextNode.tokenType = tokenType
          count += 1
        }

        continue
      }

      if index == value.lastIndex && nextNode.tokenType == nil {
        nextNode.tokenType = tokenType
        count += 1
      }
      currentNode = nextNode
    }
  }

  mutating func insert<S: Sequence>(contentsOf values: S, tokenType: Lexer.TokenType)
    where S.Iterator.Element == ByteString.Byte
  {

    for value in values {
      insert(ByteString([value]), tokenType: tokenType)
    }
  }

  func contains(_ value: ByteString) -> Lexer.TokenType? {

    var currentNode = root

    for byte in value {
      guard let nextNode = currentNode[byte] else { return nil }

      currentNode = nextNode
    }

    return currentNode.tokenType
  }
}

extension Trie {

  class Node {

    var tokenType: Lexer.TokenType? = nil
    var value: ByteString.Byte
    var children: [ByteString.Byte: Node] = [:]

    init(_ value: ByteString.Byte, tokenType: Lexer.TokenType? = nil) {

      self.tokenType = tokenType
      self.value = value
    }

    subscript(_ key: ByteString.Byte) -> Node? {

      get { return children[key] }
      set { children[key] = newValue }
    }

    var isEnd: Bool {
      return children.isEmpty
    }
  }
}