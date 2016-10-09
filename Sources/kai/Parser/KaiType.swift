
enum KaiType {
  case integer
  case boolean
  case float
  case string

  /// The type all Type's have
  case type
  case unknown(ByteString)
  case tuple([KaiType])
  case other(ByteString)
  indirect case procedure(labels: [ByteString]?, arguments: [KaiType], returnType: KaiType)
}

extension KaiType: Equatable {

  static func == (lhs: KaiType, rhs: KaiType) -> Bool {

    switch (lhs, rhs) {
    case (.unknown(let l), .unknown(let r)):
      return l == r

    case (.tuple(let l), .tuple(let r)):
      return l == r

    case (.other(let l), .other(let r)):
      return l == r

    // TODO(vdka): Currently we do not compare the labels to see if they are equal
    case let (.procedure(labels: _, arguments: largs, returnType: lreturns), .procedure(labels: _, arguments: rargs, returnType: rreturns)):
      return largs == rargs && lreturns == rreturns

    default:
      return isMemoryEquivalent(lhs, rhs)
    }
  }
}

extension KaiType: CustomStringConvertible {

  var description: String {
    switch self {
    case .boolean: return "Bool"
    case .integer: return "Int"
    case .float: return "Float"
    case .string: return "String"
    case .type: return "Type"
    case .other(let val): return val.description
    case .unknown(let val): return val.description
    case .tuple(let vals): return "(" + vals.map(String.init(describing:)).joined(separator: ", ") + ")"
    case .procedure(labels: let labels, arguments: let arguments, returnType: let returnType):

      var desc = "("
      if let labels = labels {
        desc += zip(labels, arguments)
          .map { label, type in label.description + ": " + type.description }
          .joined(separator: ",")
        desc += ")"
      } else {
        desc += arguments.map(String.init(describing:)).joined(separator: ", ") + ")"
      }

      desc += " -> "
      desc += returnType.description

      return desc
    }
  }
}
