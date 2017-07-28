
import Foundation
import Core

guard CommandLine.arguments.count > 1 else {
    print("ERROR: No input file")
    exit(1)
}

let filepath = CommandLine.arguments[1]
guard let file = SourceFile.new(path: filepath) else {
    print("ERROR: No such file or directory '\(filepath)'")
    exit(1)
}

file.parseEmittingErrors()
