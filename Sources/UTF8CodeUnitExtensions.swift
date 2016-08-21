
// MARK: - Stdlib extensions

extension UTF8.CodeUnit {

  var isWhitespace: Bool {
    if self == space || self == tab || self == cr || self == newline || self == formfeed {
      return true
    } else {
      return false
    }
  }
}
