
import Foundation

var currentDirectory = FileManager.default.currentDirectoryPath
let fileExtension = ".cte"
var buildDirectory = currentDirectory + "/" + fileExtension + "/"

var moduleName: String!

var knownSourceFiles: [String: SourceFile] = [:]

// sourcery:noinit
public final class SourceFile {

    weak var firstImportedFrom: SourceFile?
    var isInitialFile: Bool {
        return firstImportedFrom == nil
    }

    /// The base offset for this file
    var base: Int
    var size: Int
    var lineOffsets: [Int] = [0]
    var linesOfSource: Int = 0

    var errors: [SourceError] = []
    var notes: [Int: [String]] = [:]

    var nodes: [Node] = []

    var handle: FileHandle
    var fullpath: String

    var stage: String = ""
    var hasBeenParsed: Bool = false
    var hasBeenChecked: Bool = false
    var hasBeenGenerated: Bool = false

    var pathFirstImportedAs: String
    var imports: [Import] = []

    // Set in Checker
//    var scope: Scope!
//    var linkedLibraries: Set<String> = []

    init(handle: FileHandle, fullpath: String, pathImportedAs: String, importedFrom: SourceFile?) {
        self.handle = handle
        self.fullpath = fullpath
        self.pathFirstImportedAs = pathImportedAs
        self.firstImportedFrom = importedFrom
        self.base = 1
        self.size = Int(handle.seekToEndOfFile())
        handle.seek(toFileOffset: 0)
    }

    /// - Returns: nil iff the file could not be located or opened for reading
    public static func new(path: String, importedFrom: SourceFile? = nil) -> SourceFile? {

        var pathRelativeToInitialFile = path

        if let importedFrom = importedFrom {
            pathRelativeToInitialFile = dirname(path: importedFrom.fullpath) + path
        }

        guard let fullpath = realpath(relpath: pathRelativeToInitialFile) else {
            return nil
        }

        if let existing = knownSourceFiles[fullpath] {
            return existing
        }

        guard let handle = FileHandle(forReadingAtPath: fullpath) else {
            return nil
        }

        let sourceFile = SourceFile(handle: handle, fullpath: fullpath, pathImportedAs: path, importedFrom: importedFrom)
        knownSourceFiles[fullpath] = sourceFile

        return sourceFile
    }
}

extension SourceFile {

    public func parseEmittingErrors() {
        assert(!hasBeenParsed)
        stage = "Parsing"
        var parser = Parser(file: self)
        self.nodes = parser.parseFile()

        let importedFiles = imports.map({ $0.file })

        for importedFile in importedFiles {
            guard !importedFile.hasBeenParsed else {
                continue
            }
            importedFile.parseEmittingErrors()
        }

        hasBeenParsed = true

        emitErrors(for: self, at: stage)
    }
}

extension SourceFile {
    
    func addLine(offset: Int) {
        assert(lineOffsets.count == 0 || lineOffsets.last! < offset)
        lineOffsets.append(offset)
    }

    func pos(offset: Int) -> Pos {
        assert(offset <= self.size)
        return base + offset
    }

    func offset(pos: Pos) -> Int {
        assert(pos >= base && pos <= base + size)
        return pos - base
    }

    func position(for pos: Pos) -> Position {
        return unpack(offset: offset(pos: pos))
    }

    func position(forOffset offset: Int) -> Position {
        return unpack(offset: offset)
    }

    func unpack(offset: Int) -> Position {
        var line, column: Int
        if let firstPast = lineOffsets.enumerated().first(where: { $0.element > offset }) {
            let i = firstPast.offset - 1
            line = i + 1
            column = offset - lineOffsets[i] + 1
        } else {
            (line, column) = (0, 0)
        }
        return Position(filename: pathFirstImportedAs, offset: offset, line: line, column: column)
    }

    func addError(_ msg: String, _ pos: Pos, line: UInt = #line) {
        let error = SourceError(pos: pos, msg: msg)
        errors.append(error)
        #if DEBUG
        attachNote("In \(stage), line \(line)")
        attachNote("At an offset of \(offset(pos: pos)) in the file")
        #endif
    }

    func attachNote(_ message: String) {
        assert(!errors.isEmpty)

        guard var existingNotes = notes[errors.endIndex - 1] else {
            notes[errors.endIndex - 1] = [message]
            return
        }
        existingNotes.append(message)
        notes[errors.endIndex - 1] = existingNotes
    }
}

