#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public struct Options {
    public static let version = "0.0.0"

    public var flags: Flags = []
    public var jobs: Int = 1

    public var optimizationLevel: Int = 0

    public init(arguments: ArraySlice<String>) {

        var skip = false
        let pairs = arguments.indices.map({ (arguments[$0], arguments[safe: $0 + 1]) })
        for (arg, val) in pairs {
            guard !skip else {
                skip = false
                continue
            }
            switch arg {
            case "-Onone":
                if optimizationLevel != 0 {
                    print("WARNING: Multiple optimization levels specified")
                }
                optimizationLevel = 0
            case "-O1":
                if optimizationLevel != 0 {
                    print("WARNING: Multiple optimization levels specified")
                }
                optimizationLevel = 1
            case "-O2":
                if optimizationLevel != 0 {
                    print("WARNING: Multiple optimization levels specified")
                }
                optimizationLevel = 2
            case "-O3":
                if optimizationLevel != 0 {
                    print("WARNING: Multiple optimization levels specified")
                }
                optimizationLevel = 3
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
            case "-test":
                flags.insert(.testMode)
            case "-jobs":
                guard let v = val, let j = Int(v) else {
                    print("ERROR: -jobs expects an integer following it")
                    exit(1)
                }
                jobs = j
                skip = true
            case "-help":
                emitHelp()
            case "-version":
                emitVersion()
            default:
                if val != nil {
                    print("WARNING: argument unused during compilation: '\(arg)'")
                }
            }
        }
    }

    public func emitHelp() {
        let purple = "\u{001B}[35m"
        let reset = "\u{001B}[0m"

        print("\(purple)OVERVIEW\(reset): Kai compiler\n")

        print("\(purple)USAGE\(reset): kai [options] <inputs>\n")

        print("\(purple)OPTIONS\(reset):")
        print("  -dump-ir               Dump LLVM IR")
        print("")
        print("  -emit-asm              Emit assembly file(s)")
        print("  -emit-ast              Parse, check and emit AST file(s)")
        print("  -emit-bitcode          Emit LLVM bitcode file(s)")
        print("  -emit-ir               Emit LLVM IR file(s)")
        print("  -emit-times            Emit times for each stage of compilation")
        print("")
        print("  -jobs <value>          Controls the amount of workers (default is # of cores)")
        print("")
        print("  -version               Show version information and exit")
        exit(0)
    }

    public func emitVersion() {
        print("Kai version \(Options.version)")
        exit(0)
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

        public static let testMode = Flags(rawValue: 0b1000 << 8)
    }
}
