import LLVM
import Console
import Foundation

var linkedLibraries: Set<String> = []

enum OptimisationLevel: Int {
    case O0, O1, O2, O3
    
    init(_ string: String) {
        switch string {
        case "O0":
            self = .O0
            
        case "O1":
            self = .O1
            
        case "O2":
            self = .O2
            
        case "O3":
            self = .O3
            
        default:
            self = .O0
        }
    }
}

extension OptimisationLevel: Comparable {
    static func <(lhs: OptimisationLevel, rhs: OptimisationLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static func <=(lhs: OptimisationLevel, rhs: OptimisationLevel) -> Bool {
        return lhs.rawValue <= rhs.rawValue
    }
    
    static func >(lhs: OptimisationLevel, rhs: OptimisationLevel) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
    
    static func >=(lhs: OptimisationLevel, rhs: OptimisationLevel) -> Bool {
        return lhs.rawValue > rhs.rawValue
    }
}

class Compiler {
    enum Error: Swift.Error {
        case fileNameNotProvided
    }

    let console: Terminal
    let fileManager: FileManager

    let args: [String]
    let fileName: String?
    
    static var optimisationLevel: OptimisationLevel = .O1
    
    let version = "0.0.0"

    var currentDirectory: String {
        return fileManager.currentDirectoryPath
    }

    init(args: [String]) {
        console = Terminal(arguments: args)
        fileManager = FileManager.default
        fileName = args.last
        self.args = Array(args.dropFirst())
    }

    func run() throws {
        var options: Set<String> = []
        var optimizations: [String] = []

        args.forEach {
            switch $0 {
            case "--help", "-h":
                printHelp()

            case "--version", "-v":
                printVersion()

            case "--emit-ast":
                options.insert("emit-ast")

            case "--emit-typed-ast":
                options.insert("emit-typed-ast")

            case "--emit-ir":
                options.insert("emit-ir")

            case "--emit-time":
                options.insert("emit-time")

            case "--emit-all":
                options.insert("emit-ast")
                options.insert("emit-typed-ast")
                options.insert("emit-ir")
                options.insert("emit-time")

            case "-O0", "--O0", "--Onone":
                optimizations.append("O0")

            case "-O1", "--O1":
                optimizations.append("O1")

            case "-O2", "--O2":
                optimizations.append("O2")

            case "-O3", "--O3":
                optimizations.append("O3")

            default:
                if !$0.hasSuffix(".kai") {
                    print("invalid option: \($0)")
                }
                break
            }
        }

        //default to `O0` optimization
        if optimizations.count == 0 {
            optimizations.append("O1")
        }

        guard optimizations.count == 1 else {
            print(
                "error: multiple optimizations provided: " +
                "[\(optimizations.joined(separator: ", "))]"
            )
            exit(1)
        }

        let optimization = optimizations[0]
        Compiler.optimisationLevel = OptimisationLevel(optimization)
        
        try build(options: options, optimization: optimization)
    }

    func printVersion() {
        print("Kai version \(version)")
        exit(0)
    }

    func printHelp() {
        let cyan = "\u{001B}[35m"
        let reset = "\u{001B}[0m"

        print("\(cyan)OVERVIEW\(reset): Kai compiler\n")

        print("\(cyan)USAGE\(reset): kai [options] <inputs>\n")

        print("\(cyan)OPTIONS\(reset):")
        print("  --emit-ast             Output generated abstract syntax tree")
        print("  --emit-typed-ast       Output type annotated syntax tree")
        print("  --emit-ir              Output generated LLVM IR")
        print("  --emit-time            Output compiler profiling")
        print("  --emit-all             Output all debug information")
        print("")
        print("  --time, -t             Profile the compiler's operations")
        print("")
        print("  -O0, --O0, --Onone     Compile with no optimizations")
        print("  -O1, --O1              Compile with optimizations")
        print("  -O2, --O2              Compile with 01 and loop vectorization")
        print("  -O3, --O3              Compile with 02 and arg. promotion")
        print("")
        print("  --version, -v          Show version information and exit")

        exit(0)
    }

    func build(options: Set<String>, optimization: String) throws {

        let filePath = try extractFilePath()

        if options.contains("emit-ast"), options.count > 1 {
            print("\n === Starting Parsing === \n")
        }

        startTiming("Parsing")
        var parser = Parser(relativePath: filePath)

        let files = try parser.parseFiles()

        guard errors.isEmpty else {
            print("There were \(errors.count) errors during parsing\nexiting")
            emitErrors()
            exit(1)
        }

        if options.contains("emit-ast") {
            print()
            for file in files {
                print(file.pretty())
            }
        }

        if options.contains("emit-typed-ast"), options.count > 1 {
            print("\n === Starting Checking === \n")
        }

        startTiming("Checking")
        var checker = Checker(parser: parser)
        checker.checkParsedFiles()

        guard errors.isEmpty else {
            errors = errors.filter { !$0.contains("<invalid>") }
            print("There were \(errors.count) errors during checking\nexiting")
            emitErrors()
            exit(1)
        }

        if options.contains("emit-typed-ast") {
            for file in files {
                print(file.prettyTyped(checker))
            }
        }

        if options.contains("emit-ir"), options.count > 1 {
            print("\n === Starting IRGen === \n")
        }

        let buildPath = fileManager.currentDirectoryPath + "/.kai"

        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: buildPath, isDirectory: &isDir) {
            if !isDir.boolValue {
                print("ERROR: cannot write to output directory \(buildPath)")
            }
        } else {
            try fileManager.createDirectory(atPath: buildPath, withIntermediateDirectories: false, attributes: nil)
        }

        startTiming("Code Generation")
        var objects: [String] = []
        for file in files {

            let module = try IRGenerator.build(for: file, checker: checker)

            if options.contains("emit-ir") {
                // NOTE(vdka): This would be weird with multiple files
                // NOTE(vdka): Not sure how portable this is
                try module.print(to: "/dev/stdout")
            }
            do {
                try module.verify()
            } catch {
                module.dump()

                print("\nError did occur while verifying generated IR:\n")
                print(error)
                exit(1)
            }

            assert(file.fullpath.hasSuffix(".kai"))

            let objFilename = String(file.fullpath.split(separator: "/").last!.characters.dropLast(4))
                .appending(".o")
            let objAbsoluteFilename = [ buildPath, objFilename ].joined(separator: "/")
            objects.append(objAbsoluteFilename)

            try TargetMachine().emitToFile(module: module, type: .object, path: buildPath + "/" + objFilename)
        }
        endTiming()

        startTiming("Linking")
        let clang = getClangPath()
        var args = [
            "-o", "main" // TODO(vdka): Accept an output binary name in commandline options
        ]

        for object in objects {
            args.append(object)
        }
        for library in linkedLibraries {
            if library.hasSuffix(".framework") {

                var library = library
                library = library.components(separatedBy: ".").first!

                args.append("-framework")
                args.append(library)
            } else {
                args.append(library)
            }
        }

        shell(path: clang, args: args)
        endTiming()

        if options.contains("emit-time") {
            print("\n === Timings === \n")
            var total = 0.0
            for timing in timings {
                total += timing.duration
                print("\(timing.name) took \(String(format: "%.3f", timing.duration)) seconds")
            }
            print("Total time was \(String(format: "%.3f", total)) seconds")
        }
    }

    func extractFilePath() throws -> String {
        guard let fileName = fileName else {
            throw Error.fileNameNotProvided
        }

        let filePath: String

        // Test to see if fileName is a relative path
        if fileManager.fileExists(atPath: currentDirectory + "/" + fileName) {
            filePath = currentDirectory + "/" + fileName
        } else if fileManager.fileExists(atPath: fileName) { // Test to see if `fileName` is an absolute path
            guard let absolutePath = fileManager.absolutePath(for: fileName) else {
                fatalError("\(fileName) not found")
            }

            filePath = absolutePath
        } else { // `fileName` doesn't exist
            fatalError("\(fileName) not found")
        }

        return filePath
    }
}

InfixOperator.register("?", bindingPower: 20) { parser, cond in
    let (_, location) = try parser.consume()

    let thenExpr: AstNode
    if case .colon? = try parser.lexer.peek()?.kind {

        try parser.consume()

        // when the thenExpr is omitted then becomes the cond
        thenExpr = cond
    } else {

        thenExpr = try parser.expression(19)
    }
    try parser.consume(.colon)
    let elseExpr = try parser.expression(19)
    return AstNode.exprTernary(cond: cond, thenExpr, elseExpr, cond.startLocation ..< elseExpr.endLocation)
}

PrefixOperator.register("-")
PrefixOperator.register("+")
PrefixOperator.register("!")
PrefixOperator.register("~")

PrefixOperator.register("^")
PrefixOperator.register("*")
PrefixOperator.register("&")
PrefixOperator.register("<") { parser in
    let (_, location) = try parser.consume()

    let prevState = parser.state
    defer { parser.state = prevState }
    parser.state.insert(.disallowComma)

    let expr = try parser.expression(70)
    return AstNode.exprDeref(expr, location ..< expr.endLocation)
}

PrefixOperator.register("<<") { parser in
    let (_, location) = try parser.consume()

    let prevState = parser.state
    defer { parser.state = prevState }
    parser.state.insert(.disallowComma)

    let expr = try parser.expression(70)

    var secondChevronLocation = location
    secondChevronLocation.column += 1

    let firstDeref = AstNode.exprDeref(expr, secondChevronLocation ..< expr.endLocation)
    return AstNode.exprDeref(firstDeref, location ..< expr.endLocation)
}

InfixOperator.register("||", bindingPower: 20)
InfixOperator.register("&&", bindingPower: 30)

InfixOperator.register("&",  bindingPower: 40)
InfixOperator.register("^",  bindingPower: 40)
InfixOperator.register("|",  bindingPower: 40)

InfixOperator.register("<",  bindingPower: 50)
InfixOperator.register(">",  bindingPower: 50)
InfixOperator.register("<=", bindingPower: 50)
InfixOperator.register(">=", bindingPower: 50)
InfixOperator.register("==", bindingPower: 50)
InfixOperator.register("!=", bindingPower: 50)

InfixOperator.register("<<", bindingPower: 60)
InfixOperator.register(">>", bindingPower: 60)

InfixOperator.register("+",  bindingPower: 70)
InfixOperator.register("-",  bindingPower: 70)
InfixOperator.register("*",  bindingPower: 80)
InfixOperator.register("/",  bindingPower: 80)
InfixOperator.register("%",  bindingPower: 80)

let compiler = Compiler(args: CommandLine.arguments)
try compiler.run()
