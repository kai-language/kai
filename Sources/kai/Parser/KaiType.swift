
enum KaiType {
  case integer
  case boolean
  case float
  case string
  case other(identifier: Symbol)
}

extension KaiType: Equatable {

  static func == (lhs: KaiType, rhs: KaiType) -> Bool {

    switch (lhs, rhs) {
    case (.other(let l), .other(let r)):
      return l === r
      // TODO(vdka): should this be an actual comparison through Equatable or is reference equality what we want?

    default:
      return isMemoryEquivalent(lhs, rhs)
    }
  }
}
