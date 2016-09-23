
enum KaiType {
  case integer(ByteString)
  case string(ByteString)
  case other(identifier: ByteString)
}

extension KaiType: Equatable {

  static func == (lhs: KaiType, rhs: KaiType) -> Bool {

    switch (lhs, rhs) {
    case (.integer(let l), .integer(let r)): return l == r
    case (.string(let l), .string(let r)): return l == r
    case (.other(let l), .other(let r)): return l == r
    default: return false
    }
  }
}
