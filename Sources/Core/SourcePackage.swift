
import Foundation

var currentDirectory = FileManager.default.currentDirectoryPath
let fileExtension = ".kai"
var buildDirectory = currentDirectory + "/" + fileExtension + "/"

var cloneMutex = Mutex()
var cloneQueue: [Job] = []

var knownSourcePackages: [String: SourcePackage] = [:]

// sourcery:noinit
public final class SourcePackage {

    public weak var firstImportedFrom: SourceFile?
    public var isInitialFile: Bool {
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
    public static func new(relpath: String, importedFrom: SourceFile? = nil) -> SourcePackage? {

        var pathRelativeToInitialFile = relpath

        if let importedFrom = importedFrom {
            pathRelativeToInitialFile = dirname(path: importedFrom.fullpath) + relpath
        }

        guard let fullpath = realpath(relpath: pathRelativeToInitialFile) else {
            return nil
        }

        return SourcePackage.new(fullpath: fullpath, importedFrom: importedFrom)
    }

    /// - Returns: nil iff the file could not be located or opened for reading
    public static func new(fullpath: String, importedFrom: SourceFile? = nil) -> SourcePackage? {

        guard isDirectory(path: fullpath) else {
            return nil
        }

        if let existing = knownSourcePackages[fullpath] {
            return existing
        }

        let package = SourcePackage(files: [], fullpath: fullpath, pathImportedAs: fullpath, importedFrom: importedFrom)
        sourceFilesInDir(fullpath).forEach {
            // Adds to package
            _ = SourceFile.new(path: fullpath + "/" + $0, package: package)!
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

