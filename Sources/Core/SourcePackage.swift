
import Foundation
import LLVM

var currentDirectory = FileManager.default.currentDirectoryPath
let fileExtension = ".kai"
var buildDirectory = currentDirectory + "/" + fileExtension + "/"

var knownSourcePackages: [String: SourcePackage] = [:]

// sourcery:noinit
public final class SourcePackage {

    public weak var firstImportedFrom: SourceFile?
    public var isInitialPackage: Bool {
        return firstImportedFrom == nil
    }

    public var fullpath: String

    public var moduleName: String

    var filenoMutex = Mutex()
    var fileno: UInt32 = 1

    var hasBeenGenerated: Bool = false

    public var pathFirstImportedAs: String
    public var files: [SourceFile]

    public var dependencies: [SourcePackage] = []

    // Set in Checker
    var scope: Scope
    public var linkedLibraries: Set<String> = []

    // Set in IRGenerator
    lazy var module: Module = {
        return Module(name: moduleName)
    }()
    lazy var builder: IRBuilder = {
        return IRBuilder(module: module)
    }()

    public init(files: [SourceFile], fullpath: String, pathImportedAs: String, importedFrom: SourceFile?) {
        self.files = files
        self.fullpath = fullpath
        self.pathFirstImportedAs = pathImportedAs
        self.firstImportedFrom = importedFrom
        if let importedFrom = importedFrom {
            let commonPrefix = importedFrom.fullpath.commonPrefix(with: fullpath)
            moduleName = String(fullpath[commonPrefix.endIndex...])
        } else {
            moduleName = basename(path: fullpath)
        }
        self.scope = Scope(parent: Scope.global, isPackage: true)
    }

    /// - Returns: nil iff the file could not be located or opened for reading
    public static func new(path: String, importedFrom: SourceFile? = nil) -> SourcePackage? {

        var pathRelativeToInitialFile = path

        if let importedFrom = importedFrom {
            pathRelativeToInitialFile = dirname(path: importedFrom.fullpath) + path
        }

        guard let fullpath = realpath(relpath: pathRelativeToInitialFile) else {
            return nil
        }

        guard isDirectory(path: fullpath) else {
            return nil
        }

        if let existing = knownSourcePackages[fullpath] {
            return existing
        }

        let package = SourcePackage(files: [], fullpath: fullpath, pathImportedAs: path, importedFrom: importedFrom)
        sourceFilesInDir(fullpath).forEach {
            // Adds to package
            let sourceFile = SourceFile.new(path: fullpath + "/" + $0, package: package)!
            sourceFile.scope = package.scope
        }

        knownSourcePackages[fullpath] = package

        return package
    }

    public static func makeInitial(for filepath: String) -> SourcePackage? {
        guard let fullpath = realpath(relpath: filepath) else {
            return nil
        }
        guard !isDirectory(path: filepath) else {
            return nil
        }
        let package = SourcePackage(files: [], fullpath: fullpath, pathImportedAs: filepath, importedFrom: nil)
        // Adds itself to the package
        _ = SourceFile.new(path: fullpath, package: package)!

        knownSourcePackages[fullpath] = package
        return package
    }
}

extension SourcePackage {

    public func begin() {

        for file in files {
            threadPool.add(job: file.parsingJob)
        }
    }
}

