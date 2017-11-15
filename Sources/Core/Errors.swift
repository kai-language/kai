/*
import func Darwin.C.stdlib.exit

var errors: [String] = []
var notes: [Int: [String]] = [:]

func attachNote(_ message: String) {
    assert(!errors.isEmpty)

    guard var existingNotes = notes[errors.endIndex - 1] else {
        notes[errors.endIndex - 1] = [message]
        return
    }
    existingNotes.append(message)
    notes[errors.endIndex - 1] = existingNotes
}

func rememberError(_ message: String, at position: Position) {

    let formatted = "ERROR(" + position.description + "): " + message
    errors.append(formatted)
}
 */

public var wasError: Bool = false

struct SourceError {
    var pos: Pos
    var msg: String
}

func emitErrors(for file: SourceFile, at stage: String) {
    guard !file.errors.isEmpty else {
        return
    }

    let filteredErrors = file.errors.enumerated().filter { !$0.element.msg.contains("< invalid >") }
    if filteredErrors.isEmpty {
        fatalError("There were errors in \(file.pathFirstImportedAs), but they were all filtered out")
    }

    print("There were \(filteredErrors.count) errors during \(stage)\nexiting")

    for (offset, error) in filteredErrors {
        print("ERROR(" + file.position(for: error.pos).description + "): " + error.msg)
        if let notes = file.notes[offset] {
            for note in notes {
                print("  " + note)
            }
        }
        print()
    }
}
