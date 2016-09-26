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
//    directories if a file isn't explicitly given

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

try Operator.assignment("=")
try Operator.prefix("-")
try Operator.infix("+", bindingPower: 50)
try Operator.infix("-", bindingPower: 50)
try Operator.infix("*", bindingPower: 60)
try Operator.infix("/", bindingPower: 60)
try Operator.infix("?", bindingPower: 20) { parser, conditional in

  let thenExpression = try parser.expression()
  try parser.consume(.colon)
  let elseExpression = try parser.expression()
  return AST.Node(.conditional, children: [conditional, thenExpression, elseExpression])
}

let file = File(path: filePath)!

do {
    
    var lexer = Lexer(file)
    
    let ast = try Parser.parse(lexer)
    
    print(ast.pretty())
    
} catch {
    print("error: \(error)")
}

// print(parserGrammer.pretty())
