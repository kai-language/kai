
@available(*, deprecated)
class SymbolTable: CustomStringConvertible {

    var parent: SymbolTable? = nil
    var table: [Symbol] = []

    /// The top most symbol table. Things exported from file scope are here.
    static var global = SymbolTable()
    static var current = global

    func insert(_ symbol: Symbol) throws {
        // TODO(vdka): Depending on the discussion around #10 this check will need to be based off of the insert type.
        // IE: if it's a procedure and the arguement's do not match then the insert is allowed as it is an overload,
        // if it's a procedure and the argument's don't match then it's an invalid redefinition and we shoudl throw
        // if it's a Type then we should throw.
        guard table.index(where: { symbol.name == $0.name }) == nil else {
            throw Error(.redefinition, location: symbol.location)
        }
        table.append(symbol)
    }

    func lookup(_ name: ByteString) -> Symbol? {

        if let symbol = table.first(where: { $0.name == name }) {
            return symbol
        } else {
            return parent?.lookup(name)
        }
    }

    @discardableResult
    static func push() -> SymbolTable {
        let newTable = SymbolTable()
        newTable.parent = SymbolTable.current
        SymbolTable.current = newTable

        return newTable
    }

    @discardableResult
    static func pop() -> SymbolTable {
        guard let parent = SymbolTable.current.parent else { fatalError("SymbolTable has been over pop'd") }

        defer { SymbolTable.current = parent }

        return SymbolTable.current
    }

    struct Error: CompilerError {

        var severity: Severity
        var message: String?
        var location: SourceLocation
        var highlights: [SourceRange]

        init(_ reason: Reason, location: SourceLocation) {
            self.severity = .error
            self.message = String(describing: reason)
            self.location = location
            self.highlights = []
        }

        enum Reason: Swift.Error {
            case redefinition
        }
    }

    var description: String {

        return "scope"
    }
}
