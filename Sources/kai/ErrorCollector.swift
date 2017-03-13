
var errors: [String] = []

func reportError(_ message: String, at node: AstNode, file: StaticString = #file, line: UInt = #line) {
    let formatted = formatMessage(message, node.location.description, file, line)

    errors.append(formatted)
}

func reportError(_ message: String, at location: SourceLocation, file: StaticString = #file, line: UInt = #line) {
    let formatted = formatMessage(message, location.description, file, line)

    errors.append(formatted)
}

func reportError(_ message: String, at location: SourceRange, file: StaticString = #file, line: UInt = #line) {
    let formatted = formatMessage(message, location.description, file, line)

    errors.append(formatted)
}

func emitErrors() {
    for error in errors {
        print(error)
        print()
    }
}

fileprivate func formatMessage(_ message: String, _ location: String, _ file: StaticString, _ line: UInt) -> String {
    var formatted = "ERROR(\(location)): " + message

    #if Debug
        formatted = formatted + "\n\traised by \(file):\(line)"
    #endif

    return formatted
}
