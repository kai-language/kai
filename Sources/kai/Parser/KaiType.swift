
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

  /// - Note: There must be bindings if the procedure is native.
  indirect case procedure(labels: [(callsite: ByteString?, binding: ByteString)]?, types: [KaiType], returnType: KaiType)
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

    case (.procedure(_, let lTypes, let lReturnType), .procedure(_, let rTypes, let rReturnType)):
      return lTypes.elementsEqual(rTypes) && lReturnType == rReturnType

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
//    case .procedure(labels: let labels, arguments: let arguments, returnType: let returnType):
    case .procedure(_, let types, let returnType):

      var desc = "("
      desc += types.map({ $0.description }).joined(separator: ", ")
      desc += ")"

      desc += " -> "
      desc += returnType.description

      return desc
    }
  }
}
