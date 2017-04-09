import Foundation

@discardableResult
func shell(path launchPath: String, args arguments: [String]) -> String {
    let process = Process()
    process.launchPath = launchPath
    process.arguments = arguments
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let result = String(data: data, encoding: .utf8) else {
        panic()
    }
    
    if result.characters.count > 0 {
        let lastIndex = result.index(before: result.endIndex)
        return result[result.startIndex ..< lastIndex]
    }
    
    return result
}

func getClangPath() -> String {
    return shell(path: "/usr/bin/which", args: ["clang"])
}