
import LLVM

@available(*, deprecated)
class Symbol {
    let name: ByteString
    var source: Source
    let location: SourceLocation
    var flags: Flag

    var type: TypeRecord?

    var llvm: IRValue?

    // TODO(vdka): Overloads using the new type system

    init(_ name: ByteString, location: SourceLocation, type: TypeRecord? = nil, llvm: IRValue? = nil, flags: Flag = []) {
        self.name = name
        self.location = location
        self.source = .native
        self.type = type
        self.llvm = llvm
        self.flags = flags
    }

    enum Source {
        case native
        case llvm(ByteString)
        case extern(ByteString)
    }

    struct Flag: OptionSet {
        let rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let compileTime = Flag(rawValue: 0b0001)
    }
}

extension Symbol.Source: Equatable {
    static func ==(lhs: Symbol.Source, rhs: Symbol.Source) -> Bool {
        switch (lhs, rhs) {
        case (.native, .native),
             (.llvm, .llvm):
            return true

        case let (.extern(lhs), .extern(rhs)):
            return lhs == rhs
            
        default:
            return false
        }
    }
}

extension Symbol: CustomStringConvertible {

    var description: String {
        unimplemented()

        /*
        let red = "\u{001B}[31m"
        let magenta = "\u{001B}[35m"
        let reset = "\u{001B}[0m"
        
        if case .native = source {
            if let type = type { return "\(magenta)name\(reset)=\(red)\"\(name)\" \(magenta)type\(reset)=\(red)\"\(type)\"" }
            else { return "\(magenta)name\(reset)=\(red)\"\(name)\" \(magenta)type\(reset)=\(red)\"??\"" }
        } else {
            return "\(magenta)name\(reset)=\(red)\"\(name)\" \(magenta)type\(reset)=\(red)\"\(type?.description ?? "??")\" \(magenta)source\(reset)=\(red)\"\(source)\""
        }
        */
    }
}
