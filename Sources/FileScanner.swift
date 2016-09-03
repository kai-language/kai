


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
    self.position = Position(line: 0, column: 0, fileName: file.path)
    self.scanner = ByteScanner(Array(file))
  }
}

extension FileScanner {

  func peek(aheadBy n: Int = 0) -> Byte? {

    return scanner.peek()
  }

  @discardableResult
  mutating func pop() -> Byte {

    let byte = scanner.pop()

    if byte == "\n" {
      position.line += 1
      position.column = 0
    } else {
      position.column += 1
    }

    return byte
  }


  @discardableResult
  mutating func attemptPop() throws -> Byte {

    let byte = try scanner.attemptPop()

    if byte == "\n" {
      position.line += 1
      position.column = 0
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
