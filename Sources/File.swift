
import Darwin.C

class FileReader {

  let filePath: String

  let filePointer:  UnsafeMutablePointer<FILE>

  /// The number of bytes to read when we reach the end of a buffer
  let chunkSize: Int


  let basePointer:  UnsafeMutablePointer<UTF8.CodeUnit>

  /// This is a cursor
  var pointer:      UnsafeMutablePointer<UTF8.CodeUnit>

  var endPointer:   UnsafeMutablePointer<UTF8.CodeUnit>

  init?(file path: String, chunkSize: Int = 1024) {

    self.filePath = path

    guard let fp = fopen(path, "r") else { return nil }
    self.filePointer = fp
    self.chunkSize   = chunkSize

    self.basePointer = UnsafeMutablePointer<UTF8.CodeUnit>.allocate(capacity: chunkSize)
    self.pointer     = basePointer
    self.endPointer  = pointer
  }

  deinit {
    
    basePointer.deallocate(capacity: chunkSize)
    fclose(filePointer)
  }
}

extension FileReader: IteratorProtocol, Sequence {

  func next() -> UTF8.CodeUnit? {
    
    guard pointer != endPointer else {
      let count = fread(basePointer, MemoryLayout<UTF8.CodeUnit>.size, chunkSize, filePointer)
      guard count > 0 else { return nil }
      pointer = basePointer
      endPointer = pointer.advanced(by: count)
      return *pointer
    }

    defer { pointer = pointer.advanced(by: 1) }
    return *pointer
  }
}


