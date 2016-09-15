
enum KaiType {
  case integer(ByteString)
  case string(ByteString)
  case other(identifier: ByteString)
}
