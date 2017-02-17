
class Symbol {
    let name: ByteString
    var source: Source
    let location: SourceLocation
    var flags: Flag

    var type: KaiType?

    /// - Precondition: The current symbol table must align with where this symbol is defined.
    /// - Returns: An array of other overload's for type that are overloadable, nil otherwise
    var overloads: [Symbol]? {
        switch type {
        case .procedure(labels: _, types: _, returnType: _)?:
            return SymbolTable.current.table.filter({ $0.name == name })

        default: 
            return nil
        }
    }

    init(_ name: ByteString, location: SourceLocation, type: KaiType? = nil, flags: Flag = []) {
        self.name = name
        self.source = .native
        self.location = location
        self.type = type
        self.flags = flags
    }

    enum Source {
        case native
        case llvm(ByteString)
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let compileTime = Flag(rawValue: 0b0001)
    }
}

extension Symbol: CustomStringConvertible {

    var description: String {
        let red = "\u{001B}[31m"
        let magenta = "\u{001B}[35m"
        let reset = "\u{001B}[0m"
        
        if case .native = source {
                if let type = type { return "\(magenta)name\(reset)=\(red)\"\(name)\" \(magenta)type\(reset)=\(red)\"\(type)\"" }
            else { return "\(magenta)name\(reset)=\(red)\"\(name)\" \(magenta)type\(reset)=\(red)\"??\"" }
        } else {
            return "\(magenta)name\(reset)=\(red)\"\(name)\" \(magenta)type\(reset)=\(red)\"\(type?.description ?? "??")\" \(magenta)source\(reset)=\(red)\"\(source)\""
        }
    }
}
