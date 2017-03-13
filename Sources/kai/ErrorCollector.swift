
class ErrorCollector {

    var errors: [String] = []

    static var `default` = ErrorCollector()

    enum Source {
        case parser, checker
    }

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
        }
    }

    func formatMessage(_ message: String, _ location: String, _ file: StaticString, _ line: UInt) -> String {
        var formatted = "ERROR(\(location)): " + message

        #if DEBUG
            formatted = formatted + " raised by \(file):\(line)"
        #endif

        return formatted
    }
}

func reportError(_ message: String, at node: AstNode, to collector: ErrorCollector = ErrorCollector.default, file: StaticString = #file, line: UInt = #line) {
    collector.reportError(message, at: node, file: file, line: line)
}

func reportError(_ message: String, at location: SourceLocation, to collector: ErrorCollector = ErrorCollector.default, file: StaticString = #file, line: UInt = #line) {
    collector.reportError(message, at: location, file: file, line: line)
}

func reportError(_ message: String, at location: SourceRange, to collector: ErrorCollector = ErrorCollector.default, file: StaticString = #file, line: UInt = #line) {
    collector.reportError(message, at: location, file: file, line: line)
}
