
import func Darwin.C.exit

public struct Options {
    public static var instance = Options(arguments: [])

    public var flags: Flags = []
    public var jobs: Int = 4

    public init(arguments: ArraySlice<String>) {

        let pairs = arguments.indices.map({ (arguments[$0], arguments[safe: $0 + 1]) })
        for (arg, val) in pairs {
            switch arg {
            case "-no-cleanup":
                flags.insert(.noCleanup)
            case "-emit-ast":
                flags.insert(.emitAst)
            case "-emit-times":
                flags.insert(.emitTimes)
            case "-emit-debug-times":
                flags.insert(.emitDebugTimes)
            case "-dump-ir":
                flags.insert(.dumpIr)
            case "-emit-ir":
                flags.insert(.emitIr)
            case "-emit-bitcode":
                flags.insert(.emitBitcode)
            case "-emit-asm", "-S":
                flags.insert(.emitAssembly)
            case "-jobs":
                guard let v = val, let j = Int(v) else {
                    print("ERROR: -jobs expects an integer following it")
                    exit(1)
                }
                jobs = j
            default:
                if val != nil {
                    print("WARNING: argument unused during compilation: '\(arg)'")
                }
            }
        }
    }

    public struct Flags: OptionSet {
        public let rawValue: UInt64
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        public static let noCleanup    = Flags(rawValue: 0b0001)

        /// dumpIr will dump the IR to stdout
        public static let dumpIr       = Flags(rawValue: 0b0001 << 4)
        public static let emitIr       = Flags(rawValue: 0b0010 << 4)
        public static let emitBitcode  = Flags(rawValue: 0b0100 << 4)
        public static let emitAssembly = Flags(rawValue: 0b1000 << 4)

        public static let emitTimes      = Flags(rawValue: 0b0001 << 8)
        public static let emitDebugTimes = Flags(rawValue: 0b0010 << 8)
        public static let emitAst        = Flags(rawValue: 0b0100 << 8)
    }
}
