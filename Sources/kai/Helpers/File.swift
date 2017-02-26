
import Darwin.C

import Foundation.NSFileManager

class File {

    let path: String

    let handle:  UnsafeMutablePointer<FILE>

    /// The number of bytes to read when we reach the end of a buffer
    let chunkSize: Int


    let basePointer:    UnsafeMutablePointer<UTF8.CodeUnit>

    /// This is a cursor
    var pointer:            UnsafeMutablePointer<UTF8.CodeUnit>

    var endPointer:     UnsafeMutablePointer<UTF8.CodeUnit>

    init?(path: String, chunkSize: Int = 1024) {

        self.path = path

        guard let fp = fopen(path, "r") else { return nil }
        self.handle = fp
        self.chunkSize   = chunkSize

        self.basePointer = UnsafeMutablePointer<UTF8.CodeUnit>.allocate(capacity: chunkSize)
        self.pointer         = basePointer
        self.endPointer  = pointer
    }

    init?(relativePath: String) {

        let filePath: String

        let fm = FileManager.default
        let curDir = FileManager.default.currentDirectoryPath

        // Test to see if fileName is a relative path
        if fm.fileExists(atPath: curDir + "/" + relativePath) {
            filePath = curDir + "/" + relativePath
        } else if fm.fileExists(atPath: relativePath) { // Test to see if `fileName` is an absolute path
            guard let absolutePath = fm.absolutePath(for: relativePath) else {
                fatalError("\(relativePath) not found")
            }

            filePath = absolutePath
        } else { // `fileName` doesn't exist
            fatalError("\(relativePath) not found")
        }

        self.path = filePath

        guard let fp = fopen(path, "r") else { return nil }
        self.handle = fp

        self.chunkSize = 1024
        self.basePointer = UnsafeMutablePointer<UTF8.CodeUnit>.allocate(capacity: chunkSize)
        self.pointer         = basePointer
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

extension File {
        func generateVerboseLineOf(error position: SourceLocation) -> String {
                let line = position.line
                let column = position.column

                var currentLine: UInt = 1
                var peeked = 0

                //reset filepointer back to the beginning
                self.pointer = basePointer
                var scanner = FileScanner(file: self)
                
                var isConsuming = false
                var consumed: ByteString = ""
                while let byte = scanner.peek(aheadBy: peeked) {
                        peeked += 1
                        
                        if byte == "\n" { 
                                currentLine += 1
                                if isConsuming {
                                        break
                                }
                        }

                        if isConsuming {
                                consumed.append(byte)
                        }

                        if currentLine == line && !isConsuming {
                                isConsuming = true
                        }
                }

                //TODO(Brett): if an error message is longer than 80 characters take an
                //80 character chunk (preferably) centred around the `column`
                let TAB = "      " //4 spaces
                /*let TERM_WIDTH = 80

                let sourceLineLength = consumed.count
                let sourceLineString: String

                if sourceLineLength > TERM_WIDTH {
                        // _ _ X _ _ _ _ _ _
                        // _ _ _ _ X _ _ _ _
                        // _ _ _ _ _ _ X _ _
                } else {
                        sourceLineString = String(consumed)
                }*/

                //TODO(Brett): Cleanup creation of String, make some helper functions
                let count = column - 1
                let pointerString = String(repeating: " ", count: Int(count))
                return "\(TAB)\(String(consumed))" + "\n\(TAB)\(pointerString)^"
        }
}
