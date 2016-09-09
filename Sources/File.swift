
import Darwin.C

class File {

  let path: String

  let handle:  UnsafeMutablePointer<FILE>

  /// The number of bytes to read when we reach the end of a buffer
  let chunkSize: Int


  let basePointer:  UnsafeMutablePointer<UTF8.CodeUnit>

  /// This is a cursor
  var pointer:      UnsafeMutablePointer<UTF8.CodeUnit>

  var endPointer:   UnsafeMutablePointer<UTF8.CodeUnit>

  init?(path: String, chunkSize: Int = 1024) {

    self.path = path

    guard let fp = fopen(path, "r") else { return nil }
    self.handle = fp
    self.chunkSize   = chunkSize

    self.basePointer = UnsafeMutablePointer<UTF8.CodeUnit>.allocate(capacity: chunkSize)
    self.pointer     = basePointer
    self.endPointer  = pointer
  }

  deinit {

    basePointer.deallocate(capacity: chunkSize)
    fclose(handle)
  }
}

extension File {

  var name: String { return ByteString(ByteString(path).split(separator: "/").last!).description }
}

extension File: IteratorProtocol, Sequence {

  func next() -> UTF8.CodeUnit? {

    guard pointer != endPointer else {
      let count = fread(basePointer, MemoryLayout<UTF8.CodeUnit>.size, chunkSize, handle)
      guard count > 0 else { return nil }
      pointer = basePointer
      endPointer = pointer.advanced(by: count)
      defer { pointer = pointer.advanced(by: 1) }
      return pointer.pointee
    }

    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }
}
