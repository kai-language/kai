import Console
import Foundation

// TODO(Brett): Add colours and other terminal formatting
let console = Terminal(arguments: CommandLine.arguments)
let fileManager = FileManager.default
let currentDirectory = fileManager.currentDirectoryPath

guard let fileName = console.arguments.dropFirst().first else {
    fatalError("Please provide a file")
}

let filePath: String

//print(grammer)

// TODO(Brett): Move this into its own function and have it recursively search
//      directories if a file isn't explicitly given

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

try Operator.infix("?", bindingPower: 20) { parser, conditional in
    try parser.consume(.operator("?"))

    let thenExpression = try parser.expression()
    try parser.consume(.colon)
    let elseExpression = try parser.expression()
    return AST.Node(.conditional, children: [conditional, thenExpression, elseExpression])
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

let file = File(path: filePath)!

do {

    var lexer = Lexer(file)

    var (ast, errors) = try Parser.parse(&lexer)

    guard errors == 0 else {
        print("There were \(errors) errors during parsing\nexiting")
        exit(1)
    }

    print(ast.pretty())

    try IRGenerator.build(for: ast)

} catch let error as CompilerError {
    console.error(error.description)
    console.error(file.generateVerboseLineOf(error: error.location))
}
