import LLVM
import Console
import Foundation

struct Compiler {
    enum Error: Swift.Error {
        case fileNameNotProvided
    }

    let console: Terminal
    let fileManager: FileManager

    let args: [String]
    let fileName: String?

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

            case "--emit-docs":
                options.insert("emit-docs")

            case "--emit-ast":
                options.insert("emit-ast")

            case "--emit-typed-ast":
                options.insert("emit-typed-ast")

            case "--emit-ir":
                options.insert("emit-ir")

            case "--emit-time":
                options.insert("emit-time")

            case "--emit-all":
                options.insert("emit-docs")
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
        print("  --emit-docs            Output source code documentation comments")
        print("  --emit-ast             Output generated abstract syntax tree")
        print("  --emit-typed-ast       Output type annotated syntax tree")
        print("  --emit-ir              Output generated LLVM IR")
        print("  --emit-all             Output both AST and LLVM IR")
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

        if options.contains("emit-ast") {
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

        if options.contains("emit-docs") {
            print()
            for (node, comment) in parser.documentation {
                print(comment)
                print(node)
                print()
            }
        }

        if options.contains("emit-ast") {
            print()
            for file in files {
                print(file.pretty())
            }
        }

        if options.contains("emit-typed-ast") {
            print("\n === Starting Checking === \n")
        }

        startTiming("Checking")
        var checker = Checker(parser: parser)
        checker.checkParsedFiles()

        guard errors.isEmpty else {
            print("There were \(errors.count) errors during checking\nexiting")
            emitErrors()
            exit(1)
        }

        if options.contains("emit-typed-ast") {
            for file in files {
                print(file.prettyTyped(checker))
            }
        }

        if options.contains("emit-ir") {
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
        for file in files {

            let module = try IRGenerator.build(for: file, checker: checker)

            if options.contains("emit-ir") {
                // TODO(vdka): Do we emit file names?
                module.dump()
            }
            do {
                try module.verify()
            } catch {
                module.dump()
                
                print("Error did occur while verifying generated IR:")
                print(error)
                exit(1)
            }

            assert(file.fullpath.hasSuffix(".kai"))

            let objFilename = String(file.fullpath.split(separator: "/").last!.characters.dropLast(4))
                .appending(".o")

            try TargetMachine().emitToFile(module: module, type: .object, path: buildPath + "/" + objFilename)
        }
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

try Operator.infix("?", bindingPower: 20) { parser, cond in
    let (_, location) = try parser.consume(.operator("?"))

    let thenExpr = try parser.expression()
    try parser.consume(.colon)
    let elseExpr = try parser.expression()
    return AstNode.exprTernary(cond: cond, thenExpr, elseExpr, cond.startLocation ..< elseExpr.endLocation)
}

try Operator.prefix("-")
try Operator.prefix("+")
try Operator.prefix("!")
try Operator.prefix("~")

try Operator.prefix("*")
try Operator.prefix("&")

try Operator.infix("||",  bindingPower: 20)
try Operator.infix("&&",  bindingPower: 30)

try Operator.infix("&",   bindingPower: 40)
try Operator.infix("^",   bindingPower: 40)
try Operator.infix("|",   bindingPower: 40)

try Operator.infix("<",   bindingPower: 50)
try Operator.infix(">",   bindingPower: 50)
try Operator.infix("<=",  bindingPower: 50)
try Operator.infix(">=",  bindingPower: 50)
try Operator.infix("==",  bindingPower: 50)
try Operator.infix("!=",  bindingPower: 50)

try Operator.infix("<<", bindingPower: 60)
try Operator.infix(">>", bindingPower: 60)

try Operator.infix("+",  bindingPower: 70)
try Operator.infix("-",  bindingPower: 70)
try Operator.infix("*",  bindingPower: 80)
try Operator.infix("/",  bindingPower: 80)
try Operator.infix("%",  bindingPower: 80)

let compiler = Compiler(args: CommandLine.arguments)
try compiler.run()
