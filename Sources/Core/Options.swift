#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public struct Options {
    public static let version = "0.0.0"

    public var flags: Flags = []
    public var linkerFlags: [String] = []
    public var jobs: Int = 1
    public var outputFile: String?

    public var target: String?
    public var linker: String?
    
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
            case "-no-link":
                flags.insert(.noLink)
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
                flags.insert(.noCleanup)
            case "-emit-bitcode":
                flags.insert(.emitBitcode)
                flags.insert(.noCleanup)
            case "-emit-asm", "-S":
                flags.insert(.emitAssembly)
                flags.insert(.noCleanup)
            case "-emit-object":
                flags.insert(.emitObject)
                flags.insert(.noCleanup)
            case "-test":
                flags.insert(.testMode)
            case "-shared":
                flags.insert(.shared)
            case "-dynamiclib":
                flags.insert(.dynamicLib)
            case "-o", "-output":
                guard let v = val else {
                    print("ERROR: -o expects an output name")
                    exit(1)
                }
                outputFile = v
                skip = true
            case "-jobs":
                guard let v = val, let j = Int(v) else {
                    print("ERROR: -jobs expects an integer following it")
                    exit(1)
                }
                jobs = j
                skip = true
            case "-target":
                guard let v = val else {
                    print("ERROR: -target requires a target triple following it")
                    exit(1)
                }
                skip = true
                target = v
            case "-linker":
                guard let v = val else {
                    print("ERROR: -linker requires a linker following it")
                    exit(1)
                }
                skip = true
                linker = v
            case "-Xlinker":
                guard let v = val else {
                    print("ERROR: -Xlinker requires a flag following it")
                    exit(1)
                }
                skip = true
                let contents = v.split(separator: " ").map({ String($0) })
                linkerFlags.append(contentsOf: contents)
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

        print("\(purple)USAGE\(reset): kai [options] \u{001B}[36m<inputs>\u{001B}[0m\n")

        print("\(purple)OPTIONS\(reset):")
        print("  -dump-ir               Dump LLVM IR")
        print()
        print("  -dynamiclib            Emit dylib")
        print()
        print("  -emit-asm              Emit assembly file(s)")
        print("  -emit-ast              Parse, check and emit AST file(s)")
        print("  -emit-bitcode          Emit LLVM bitcode file(s)")
        print("  -emit-object           Emit object file(s)")
        print("  -emit-ir               Emit LLVM IR file(s)")
        print("  -emit-times            Emit times for each stage of compilation")
        print()
        print("  -o \u{001B}[36m<file>\u{001B}[0m")
        print("  -output \u{001B}[36m<file>\u{001B}[0m         Write output to file")
        print()
        print("  -jobs \u{001B}[36m<value>\u{001B}[0m          Controls the amount of workers (default is # of cores)")
        print()
        print("  -no-link               Do not link output objects")
        print("  -no-cleanup            Keeps the build folder after compilation")
        print()
        print("  -Onone                 Compile with no optimizations")
        print("  -O1                    Compile with basic optimizations")
        print("  -O2                    Compile with most optimizations")
        print("  -O3                    Compile with tail call elimination and loop unrolling")
        print()
        print("  -shared                Emit shared object")
        print()
        print("  -test                  Compile and run all unit tests")
        print()
        print("  -version               Show version information and exit")
        exit(0)
    }

    public func emitVersion() {
        print("\u{001B}[35m")
        print("   ▄█   ▄█▄    ▄████████  ▄█")
        print("  ███ ▄███▀   ███    ███ ███")
        print("  ███▐██▀     ███    ███ ███▌")
        print(" ▄█████▀      ███    ███ ███▌")
        print("▀▀█████▄    ▀███████████ ███▌")
        print("  ███▐██▄     ███    ███ ███")
        print("  ███ ▀███▄   ███    ███ ███")
        print("  ███   ▀█▀   ███    █▀  █▀\u{001B}[0m   \(Options.version)")
        print("")

        exit(0)
    }

    public struct Flags: OptionSet {
        public let rawValue: UInt64
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// dumpIr will dump the IR to stdout
        public static let dumpIr       = Flags(rawValue: (1 << 1))
        public static let emitIr       = Flags(rawValue: (1 << 2))
        public static let emitBitcode  = Flags(rawValue: (1 << 3))
        public static let emitAssembly = Flags(rawValue: (1 << 4))
        public static let emitObject   = Flags(rawValue: (1 << 5))

        public static let emitTimes      = Flags(rawValue: (1 << 6))
        public static let emitDebugTimes = Flags(rawValue: (1 << 7))
        public static let emitAst        = Flags(rawValue: (1 << 8))

        public static let testMode  = Flags(rawValue: (1 <<  9))
        public static let noLink    = Flags(rawValue: (1 << 10))
        public static let noCleanup = Flags(rawValue: (1 << 11))

        public static let shared     = Flags(rawValue: (1 << 12))
        public static let dynamicLib = Flags(rawValue: (1 << 13))
    }
}
