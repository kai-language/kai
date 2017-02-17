
fileprivate typealias RecoveryStrategy = Parser.RecoveryStrategy

extension Parser {

    mutating func error(_ reason: Error.Reason, location: SourceLocation? = nil) -> Parser.Error {
        errors += 1
        return Error(reason: reason, message: reason.description, severity: .error, location: location ?? lexer.lastLocation, highlights: [])
    }
}

extension Parser {

    struct Error: CompilerError {

        var reason: Reason
        var message: String?
        var severity: Severity
        var location: SourceLocation
        var highlights: [SourceRange]

        enum Reason: Swift.Error {
            // new
            case expectedMemberName
            case expectedComma
            case unexpectedComma
            case trailingComma
            case expectedForeignName
            case expectedExpression
            case unknownAssociativity
            case nonInfixOperator(Lexer.Token)

            // old
            case expected(ByteString)
            case unexpected(ByteString)
            case undefinedIdentifier(ByteString)
            case operatorRedefinition
            case unaryOperatorBodyForbidden
            case ambigiousOperatorUse
            case expectedBody
            case expectedPrecedence
            case expectedOperator
            case invalidDeclaration
            case syntaxError
            case badlvalue

            var description: String {

                switch self {
                case .expectedExpression: return "Expected Expression"
                case .badlvalue: return "Bad lvalue"
                case .operatorRedefinition: return "Invalid redefinition"
                case .expectedComma: return "Expected a comma"
                case .expectedPrecedence: return "Expected Precedence"
                case .expectedOperator: return "Expected an Operator definition or declaration"
                case .unknownAssociativity: return "Unknown value for associativity. Valid values are (left|none|right)"
                case .unexpectedComma, .trailingComma: return "Comma was not expected" // TODO(vdka): Try again.
                case .expectedMemberName: return "Expected member name"
                case .expectedForeignName: return "Expected a name for foreign symbol"
                case .nonInfixOperator(let token): return "No infix operator found for \(token)" // TODO(vdka): Could probably use refinement

                default: return "TODO"
                }
            }
        }
    }
}

extension Parser.Error {

    func recover(with parser: inout Parser, using recovery: (inout Parser) throws -> Void) throws {
        try recovery(&parser)
    }

    func recover(with parser: inout Parser) throws {
        guard let recovery = reason.recovery else { throw self }
        print(self)

        try recovery(&parser)
    }
}

extension Parser.Error.Reason {

    var recovery: ((inout Parser) throws -> Void)? {

        switch self {
        case .expectedExpression:
            return RecoveryStrategy.consumeAndContinue

        case .expectedComma, .trailingComma, .unexpectedComma:
            return RecoveryStrategy.continue

        case .expectedForeignName:
            return RecoveryStrategy.continue

        case .expectedMemberName:
            return RecoveryStrategy.consumeAndContinue

        default:
            return nil
        }
    }
}

extension Parser.Error.Reason: Equatable {

    static func == (lhs: Parser.Error.Reason, rhs: Parser.Error.Reason) -> Bool {

        switch (lhs, rhs) {
        case (.expected(let l), .expected(let r)): return l == r
        case (.undefinedIdentifier(let l), .undefinedIdentifier(let r)): return l == r
        default: return isMemoryEquivalent(lhs, rhs)
        }
    }
}
