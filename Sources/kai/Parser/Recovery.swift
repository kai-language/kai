
extension Parser {

    enum RecoveryStrategy {

        static let `continue`: (inout Parser) throws -> Void = { _ in }
        static let consumeAndContinue: (inout Parser) throws -> Void = { parser in try parser.consume() }
    }
}
