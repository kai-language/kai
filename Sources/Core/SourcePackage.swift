
import Foundation
import LLVM

var currentDirectory = FileManager.default.currentDirectoryPath
let fileExtension = ".kai"
var buildDirectory = currentDirectory + "/" + fileExtension + "/"

var knownSourcePackages: [String: SourcePackage] = [:]
var dependencyPath = currentDirectory + "/deps"

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
    lazy var passManager: FunctionPassManager = {
        let pm = FunctionPassManager(module: module)

        let optLevel = Options.instance.optimizationLevel
        guard optLevel > 0 else { return pm }

        pm.add(.basicAliasAnalysis, .instructionCombining, .aggressiveDCE, .reassociate, .promoteMemoryToRegister)

        guard optLevel > 1 else { return pm }

        pm.add(.gvn, .cfgSimplification)

        guard optLevel > 2 else { return pm }

        pm.add(.tailCallElimination, .loopUnroll)

        return pm
    }()

    public init(files: [SourceFile], fullpath: String, pathImportedAs: String, importedFrom: SourceFile?) {
        self.files = files
        self.fullpath = fullpath
        self.pathFirstImportedAs = pathImportedAs
        self.firstImportedFrom = importedFrom
        if let importedFrom = importedFrom {
            let index = importedFrom.fullpath.commonPathPrefix(with: fullpath)
            moduleName = dropExtension(path: String(fullpath[index...]))
        } else {
            moduleName = dropExtension(path: basename(path: fullpath))
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
            importedFrom?.checkingJob.addDependency(sourceFile.checkingJob)
            importedFrom?.generationJob.addDependency(sourceFile.generationJob)
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

    public static func gatherLinkerFlags() -> Set<String> {
        var libs: Set<String> = []

        for (_, package) in knownSourcePackages {
            for lib in package.linkedLibraries {
                libs.insert(lib)
            }
        }

        return libs
    }
}

extension SourcePackage {

    public func begin() {
        for file in files {
            threadPool.add(job: file.parsingJob)
        }
    }

    public var emitPath: String {
        return buildDirectory + moduleName
    }

    public var objpath: String {
        return emitPath + ".o"
    }

    public func validateIR() {
        for dependency in dependencies {
            dependency.validateIR()
        }

        do {
            try module.verify()
        } catch {
            try! module.print(to: "/dev/stdout")
            print(error)
            exit(1)
        }
    }

    public func emitObjects() {
        for dep in dependencies {
            dep.emitObjects()
        }

        do {
            try targetMachine.emitToFile(
                module: module,
                type: .object,
                path: objpath
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting object file to \(emitPath)")
            exit(1)
        }
    }

    public func emitIntermediateRepresentation() {
        for dep in dependencies {
            dep.emitIntermediateRepresentation()
        }

        do {
            try module.print(to: emitPath + ".ll")
        } catch {
            print("ERROR: \(error)")
            print("  While emitting IR to '\(emitPath + ".ll")'")
            exit(1)
        }
    }

    public func dumpIntermediateRepresentation() {
        for dep in dependencies {
            dep.dumpIntermediateRepresentation()
        }
        module.dump()
        print()
    }

    public func emitBitcode() {
        for dep in dependencies {
            dep.emitBitcode()
        }

        do {
            try targetMachine.emitToFile(
                module: module,
                type: .bitCode,
                path: emitPath + ".bc"
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting Bitcode to '\(emitPath + ".bc")'")
            exit(1)
        }
    }

    public func emitAssembly() {
        for dep in dependencies {
            dep.emitAssembly()
        }

        do {
            try targetMachine.emitToFile(
                module: module,
                type: .assembly,
                path: emitPath + ".s"
            )
        } catch {
            print("ERROR: \(error)")
            print("  While emitting Assembly to '\(emitPath + ".s")'")
            exit(1)
        }
    }

    public func linkObjects() {
        let clangPath = getClangPath()

        let objFilePaths = knownSourcePackages.values.map({ $0.objpath })
        var args = ["-o", moduleName] + objFilePaths

        let allLinkedLibraries = knownSourcePackages.values.reduce(Set(), { $0.union($1.linkedLibraries) })
        for library in allLinkedLibraries {
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

        shell(path: clangPath, args: args)
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
