
import Foundation

typealias FileNo = UInt32

let noPos: Pos = Pos(fileno: 0, offset: 0)
struct Pos: Comparable {
    var fileno: FileNo
    var offset: UInt32

    static func + (lhs: Pos, rhs: Int) -> Pos {
        var pos = lhs
        pos.offset += UInt32(rhs)
        return pos
    }

    static func - (lhs: Pos, rhs: Int) -> Pos {
        var pos = lhs
        pos.offset -= UInt32(rhs)
        return pos
    }

    static func ==(lhs: Pos, rhs: Pos) -> Bool {
        return lhs.offset == rhs.offset && rhs.fileno == rhs.fileno
    }

    static func <(lhs: Pos, rhs: Pos) -> Bool {
        return lhs.offset < rhs.offset && rhs.fileno == rhs.fileno
    }
}


struct SourceLocation: CustomStringConvertible {

    /// filename
    var filename: String
    /// offset, starting at 0
    var offset: UInt32
    /// line number, starting at 1
    var line: UInt32
    /// column number, starting at 1 (byte count)
    var column: UInt32

    var description: String {
        let filename = basename(path: self.filename)
        return "\(filename):\(line):\(column)"
    }
}

extension SourcePackage {

    func file(for fileno: UInt32) -> SourceFile? {
        if fileno == 0 {
            return nil
        }

        return files[safe: numericCast(fileno - 1)]
    }

    func position(for pos: Pos) -> SourceLocation? {
        let file = self.file(for: pos.fileno)
        return file?.unpack(offset: pos.offset)
    }

    func sourceCode(from: Pos, to: Pos) -> String {
        guard let file = self.file(for: from.fileno) else {
            return ""
        }

        return file.sourceCode(from: from, to: to)
    }
}

extension SourceFile {

    func sourceCode(from: Pos, to: Pos) -> String {
        assert(from.fileno == to.fileno && fileno == from.fileno)
        assert(from.offset < to.offset)

        // NOTE: Handles are closed again after checking completes them
        // TODO: There is a possibility of file a reporting an error referencing a chunk
        //  of file b after file b has finished checking this would leave a handle open?
        guard let handle = handle ?? FileHandle(forReadingAtPath: fullpath) else {
            print("Error couldn't open file at path fullpath (was it deleted?)")
            return ""
        }

        self.handle = handle
        handle.seek(toFileOffset: numericCast(from.offset))
        let data = handle.readData(ofLength: numericCast(to.offset - from.offset))
        return String(data: data, encoding: .utf8)!
    }

    func position(for pos: Pos) -> SourceLocation {
        return unpack(offset: pos.offset)
    }

    func unpack(offset: UInt32) -> SourceLocation {
        var line, column: UInt32
        if let firstPast = lineOffsets.enumerated().first(where: { $0.element > offset }) {
            let i = firstPast.offset - 1
            line = UInt32(i) + 1
            column = offset - lineOffsets[i] + 1
        } else {
            (line, column) = (0, 0)
        }
        return SourceLocation(filename: pathFirstImportedAs, offset: offset, line: line, column: column)
    }
}
