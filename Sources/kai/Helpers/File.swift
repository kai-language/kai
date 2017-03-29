
import Darwin.C

struct File {
    let path: String
    let data: String

    /// 
    init?(path: String) {
        self.path = path

        guard let fp = fopen(path, "r") else { return nil }
        defer { fclose(fp) }

        // Read the whole file and store the contents.
        var data = ""

        let chunkSize = 1024
        let buffer: UnsafeMutablePointer<CChar> = UnsafeMutablePointer.allocate(capacity: chunkSize + 1) // 1 byte for a null pointer.
        buffer[chunkSize + 1] = 0 // null term
        defer { buffer.deallocate(capacity: chunkSize) }
        repeat {
            let count: Int = fread(buffer, 1, chunkSize - 1, fp)
            guard ferror(fp) == 0 else { break }
            buffer[count] = 0
            if count > 0 {
                let ptr = UnsafePointer(buffer)
                if let newString = String(validatingUTF8: ptr) {
                    data.append(newString)
                }
            }
        } while feof(fp) == 0

        self.data = data
    }
}

extension File {

    var name: String { return path.split(separator: "/").last! }
}


extension File: Sequence {

    func makeIterator() -> AnyIterator<UnicodeScalar> {

        let iter = data.unicodeScalars.makeIterator()
        return AnyIterator(iter)
    }
}
