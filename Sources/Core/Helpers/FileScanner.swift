
import Foundation

struct FileScanner {

    var line: Int = 1
    var column: Int = 1
    var offset: Int = 0
    var scalars: [Unicode.Scalar] = []

    init?(handle: FileHandle) {
        let data = handle.readDataToEndOfFile()
        let wasError = transcode(data.makeIterator(), from: UTF8.self, to: Unicode.UTF32.self, stoppingOnError: true) { rune in
            let scalar = unsafeBitCast(rune, to: Unicode.Scalar.self)
            scalars.append(scalar)
        }
        if wasError {
            return nil
        }
    }
}

extension FileScanner {

    func peek(aheadBy n: Int = 0) -> Unicode.Scalar? {

        if offset + n <= scalars.endIndex - 1 {
            return scalars[offset + n]
        }
        return nil
    }

    /// - Precondition: Call to peek first to ensure the underlying sequence has not been exhausted
    @discardableResult
    mutating func pop() -> Unicode.Scalar {
        guard offset < scalars.endIndex else {
            fatalError()
        }
        let scalar = scalars[offset]

        offset += 1
        if scalar == "\n" {
            column = 1
            line += 1
        } else {
            column += 1
        }


        return scalar
    }

    mutating func pop(_ n: Int) {
        offset += n
    }

    mutating func hasPrefix(_ prefix: String) -> Bool {
        return zip(prefix.unicodeScalars, scalars).reduce(true, { $0 && $1.0 == $1.1 })
    }

    mutating func prefix(_ n: Int) -> String {
        let prefix = scalars.prefix(n)
        return String(prefix)
    }
}
