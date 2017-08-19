
import Foundation
import LLVM

var currentDirectory = FileManager.default.currentDirectoryPath
let fileExtension = ".kai"
var buildDirectory = currentDirectory + "/" + fileExtension + "/"

var cloneMutex = Mutex()
var cloneQueue: [Job] = []

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
        var context: Context? = nil

        // LLVM contexts aren't thread safe. So, each thread gets its own. The
        // initial package gets `global`.
        if !isInitialPackage {
            context = Context()
        }

        return Module(name: moduleName, context: context)
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
            let index = importedFrom.fullpath.commonPathPrefix(with: fullpath)
            moduleName = String(fullpath[index...])
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

    public static func exportAll() {
        initTargetMachine()
        validateAll()

        for (_, package) in knownSourcePackages {
            package.compileIntermediateRepresentation()
        }
    }

    public static func validateAll() {
        for (_, package) in knownSourcePackages {
            package.validateIntermediateRepresentation()
        }
    }

    public static func gatherLinkerFlags() -> Set<String> {
        var libs: Set<String> = []

        for (_, package) in knownSourcePackages {
            for lib in package.linkedLibraries {
                libs.insert(lib)
            }
        }

        return libs
    }

    public static func emitAllIr() {
        for (_, package) in knownSourcePackages {
            package.emitIr()
        }

        print()
    }
}

extension SourcePackage {

    public func begin() {
        for file in files {
            threadPool.add(job: file.parsingJob)
        }
    }

    public var objpath: String {
        return buildDirectory + moduleName + ".o"
    }

    public func validateIntermediateRepresentation() {
        do {
            try module.verify()
        } catch {
            try! module.print(to: "/dev/stdout")
            print(error)
            exit(1)
        }
    }

    public func compileIntermediateRepresentation() {
        do {
            try targetMachine.emitToFile(
                module: module,
                type: .object,
                path: objpath
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting object file to \(objpath)")
            exit(1)
        }
    }

    public func link() {
        let clangPath = getClangPath()

        var args = ["-o", moduleName, objpath]
        for library in linkedLibraries {
            if library.hasSuffix(".framework") {

                let frameworkName = library.components(separatedBy: ".").first!

                args.append("-framework")
                args.append(frameworkName)

                guard library == basename(path: library) else {
                    print("ERROR: Only system frameworks are supported")
                    exit(1)
                }
            } else {
                args.append(library)
            }
        }

        shell(path: clangPath, args: ["-o", moduleName, objpath])
    }

    public func cleanupBuildProducts() {
        do {
            try removeFile(at: buildDirectory)
        } catch {
            print("ERROR: \(error)")
            print("  While cleaning up build directory")
            exit(1)
        }
    }

    public func emitIr() {
        do {
            try module.print(to: "/dev/stdout")
        } catch {
            print("ERROR: \(error)")
            print("  While emitting IR to '/dev/stdout'")
            exit(1)
        }
    }

    public func emitBitcode() {
        do {
            try targetMachine.emitToFile(
                module: module,
                type: .bitCode,
                path: "/dev/stdout"
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting Bitcode")
            exit(1)
        }
    }

    public func emitAssembly() {
        do {
            try targetMachine.emitToFile(
                module: module,
                type: .assembly,
                path: "/dev/stdout"
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting Assembly")
            exit(1)
        }
    }
}

extension String {
    func commonPathPrefix(with rhs: String) -> String.Index {
        let lhs = self
        let count = lhs.count > rhs.count ? lhs.count : rhs.count

        var lastPath = 0
        for i in 0..<Int(count) {
            let a = lhs[lhs.index(lhs.startIndex, offsetBy: i)]
            let b = rhs[rhs.index(rhs.startIndex, offsetBy: i)]

            guard a == b else {
                if lastPath > 0 { lastPath += 1 } // don't include the final `/`
                return lhs.index(lhs.startIndex, offsetBy: lastPath)
            }

            if a == "/" {
                lastPath = i
            }
        }

        return lhs.index(lhs.startIndex, offsetBy: count)
    }
}