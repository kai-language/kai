
class Trie<KeyPath: BidirectionalCollection, Value>
  where KeyPath.Iterator.Element: Equatable, KeyPath.Index == Int
{

  typealias Key = KeyPath.Iterator.Element

  typealias Node = Trie<KeyPath, Value>

  var key: Key
  var value: Value?
  var children: [Trie.Node] = []

  init(key: Key, value: Value? = nil) {
    self.key = key
    self.value = value
  }
}

extension Trie {

  subscript(key: Key) -> Trie.Node? {

    get { return children.first(where: { $0.key == key }) }
    set {
      guard let index = children.index(where: { $0.key == key }) else {
        guard let newValue = newValue else { return }
        children.append(newValue)

        return
      }

      guard let newValue = newValue else {
        children.remove(at: index)
        return
      }

      let existing = children[index]

      if existing.value == nil {
        existing.value = newValue.value
      } else {
        print("WARNING: You have inserted duplicates into your grammer")
      }
    }
  }

  func insert(_ keyPath: KeyPath, value: Value) {
    insert(value, forKeyPath: keyPath)
  }

  func insert(_ value: Value, forKeyPath keys: KeyPath) {

    var currentNode = self

    for (index, key) in keys.enumerated() {

      guard let nextNode = currentNode[key] else {
        let nextNode = Trie.Node(key: key, value: nil)
        currentNode[key] = nextNode
        currentNode = nextNode

        if index == keys.lastIndex {
          nextNode.value = value
        }

        continue
      }

      if index == keys.lastIndex && nextNode.value == nil {
        nextNode.value = value
      }

      currentNode = nextNode
    }
  }

  func contains(_ keyPath: KeyPath) -> Value? {
    var currentNode = self

    for key in keyPath {
      guard let nextNode = currentNode[key] else { return nil }

      currentNode = nextNode
    }

    return currentNode.value
  }
}

extension Trie
  // where Key: CustomStringConvertible, Value: CustomStringConvertible
{
  func pretty(depth: Int = 0) -> String {


    let payload: String
    if let value = self.value {
      payload = " -> \(value)"
    } else {
      payload = ""
    }

    let children = self.children
//      .sorted { $0.1.value < $1.1.value }
      .map { $0.pretty(depth: depth + 1) }
      .reduce("", { $0 + $1})

    let pretty = "- \(key)\(payload)" + "\n" + "\(children)"

    let indentation = (0...depth).reduce("", { $0.0 + " " })

    return "\(indentation)\(pretty)"
  }
}
