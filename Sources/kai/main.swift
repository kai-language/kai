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
                
            case "--emit-ast":
                options.insert("emit-ast")
                
            case "--emit-ir":
                options.insert("emit-ir")
                
            case "--emit-all":
                options.insert("emit-ast")
                options.insert("emit-ir")
                
            case "--time", "-t":
                options.insert("time")
                
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
        print("  --emit-ast             Output generated abstract syntax tree")
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
        

        var parser = Parser(relativePath: filePath)

        //            let (ast, errors) = try parser.parse()
        let files = try parser.parseFiles()

        guard errors.isEmpty else {
            print("There were \(errors.count) errors during parsing\nexiting")
            emitErrors()
            exit(1)
        }

        if options.contains("emit-ast") {
            for file in files {
                print(file.pretty())
            }
        }

        var checker = Checker(parser: parser)
        checker.checkParsedFiles()

        guard errors.isEmpty else {
            print("There were \(errors.count) errors during parsing\nexiting")
            emitErrors()
            exit(1)
        }

        for file in files {

            let module = try IRGenerator.build(for: file)

            // FIXME(vdka): emit object files for each and every importation
            try TargetMachine().emitToFile(module: module, type: .object, path: "main.o")
            if options.contains("emit-ir") {
                // TODO(vdka): Do we emit file names?
                module.dump()
            }
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
try Operator.prefix("!")
try Operator.prefix("~")

try Operator.infix("+",  bindingPower: 50)
try Operator.infix("-",  bindingPower: 50)
try Operator.infix("*",  bindingPower: 60)
try Operator.infix("/",  bindingPower: 60)
try Operator.infix("%",  bindingPower: 60)

try Operator.infix("<<", bindingPower: 70)
try Operator.infix(">>", bindingPower: 70)

try Operator.infix("<",  bindingPower: 80)
try Operator.infix("<=", bindingPower: 80)
try Operator.infix(">",  bindingPower: 80)
try Operator.infix(">=",  bindingPower: 80)
try Operator.infix("==",  bindingPower: 90)
try Operator.infix("!=",  bindingPower: 90)

try Operator.infix("&",   bindingPower: 100)
try Operator.infix("^",   bindingPower: 110)
try Operator.infix("|",   bindingPower: 120)

try Operator.infix("&&",  bindingPower: 130)
try Operator.infix("||",  bindingPower: 140)

try Operator.infix("+=",   bindingPower: 160)
try Operator.infix("-=",   bindingPower: 160)
try Operator.infix("*=",   bindingPower: 160)
try Operator.infix("/=",   bindingPower: 160)
try Operator.infix("%=",   bindingPower: 160)

try Operator.infix(">>=",  bindingPower: 160)
try Operator.infix("<<=",  bindingPower: 160)

try Operator.infix("&=",   bindingPower: 160)
try Operator.infix("^=",   bindingPower: 160)
try Operator.infix("|=",   bindingPower: 160)

let compiler = Compiler(args: CommandLine.arguments)
try compiler.run()
