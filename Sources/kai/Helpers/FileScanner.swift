
struct FileScanner {

    var file: File
    var position: SourceLocation
    var scanner: BufferedScanner<UnicodeScalar>

    init(file: File) {

        self.file = file
        self.position = SourceLocation(line: 1, column: 1, file: file.path)
        self.scanner = BufferedScanner(file.makeIterator())
    }
}

extension FileScanner {

    mutating func peek(aheadBy n: Int = 0) -> UnicodeScalar? {

        return scanner.peek(aheadBy: n)
    }

    @discardableResult
    mutating func pop() -> UnicodeScalar {

        let scalar = scanner.pop()

        if scalar == "\n" {
            position.line       += 1
            position.column  = 1
        } else {
            position.column += 1
        }

        return scalar
    }
}

extension FileScanner {

    @discardableResult
    mutating func pop(_ n: Int) {

        for _ in 0..<n { pop() }
    }
}

extension FileScanner {

    mutating func hasPrefix(_ prefix: String) -> Bool {

        for (index, char) in prefix.unicodeScalars.enumerated() {

            guard peek(aheadBy: index) == char else { return false }
        }

        return true
    }

    mutating func prefix(_ n: Int) -> String {

        var scalars: [UnicodeScalar] = []

        var index = 0
        while index < n, let next = peek(aheadBy: index) {
            defer { index += 1 }

            scalars.append(next)
        }

        return String(scalars)
    }
}
