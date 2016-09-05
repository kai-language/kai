
struct FileScanner {

  struct Position {

    var line: UInt
    var column: UInt
    var fileName: String
  }

  typealias Byte = UTF8.CodeUnit

  var file: File
  var position: Position
  var scanner: ByteScanner

  init(file: File) {

    self.file = file
    // TODO(vdka): this should start at line number 1 but that puts it all off by 1 :S
    self.position = Position(line: 0, column: 1, fileName: file.path)
    self.scanner = ByteScanner(Array(file))
  }
}

extension FileScanner {

  func peek(aheadBy n: Int = 0) -> Byte? {

    return scanner.peek(aheadBy: n)
  }

  @discardableResult
  mutating func pop() -> Byte {

    let byte = scanner.pop()

    if byte == "\n" {
      position.line   += 1
      position.column  = 1
    } else {
      position.column += 1
    }

    return byte
  }


  @discardableResult
  mutating func attemptPop() throws -> Byte {

    let byte = try scanner.attemptPop()

    if byte == "\n" {
      position.line   += 1
      position.column  = 1
    } else {
      position.column += 1
    }

    return byte
  }
}

extension FileScanner {

  @discardableResult
  mutating func pop(_ n: Int) {

    for _ in 0..<n { pop() }
  }

  @discardableResult
  mutating func attemptPop(_ n: Int) throws {

    for _ in 0..<n { try attemptPop() }
  }
}

extension FileScanner {

  func hasPrefix(_ prefix: ByteString) -> Bool {

    for (index, char) in prefix.enumerated() {

      guard self.peek(aheadBy: index) == char else { return false }
    }

    return true
  }

  func prefix(_ n: Int) -> ByteString {

    var bytes: [Byte] = []

    var index = 0
    while index < n, let next = peek(aheadBy: index) {
      defer { index += 1 }

      bytes.append(next)
    }

    return ByteString(bytes)
  }
}
