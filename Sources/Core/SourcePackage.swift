
import Foundation
import LLVM

var currentDirectory = FileManager.default.currentDirectoryPath
let fileExtension = ".kai"
var buildDirectory = currentDirectory + "/" + fileExtension + "/"

var dependencyPath = currentDirectory + "/deps"

// NOTE: When we return to being multithreaded we will need to have this be ThreadLocal
var currentPackage: SourcePackage!

// sourcery:noinit
public final class SourcePackage {

    public weak var firstImportedFrom: SourceFile?

    public var fullpath: String

    public var moduleName: String

    var filenoMutex = Mutex()
    var fileno: UInt32 = 1

    public var pathFirstImportedAs: String
    public var files: [SourceFile]

    var emitted: Bool = false

    var cost: UInt? = nil

    public var dependencies: [SourcePackage] = []

    // Set in Checker
    var scope: Scope
    public var linkedLibraries: Set<String> = []

    // Set in IRGenerator
    lazy var module: Module = {
        var context: Context? = nil

        // LLVM contexts aren't thread safe. So, each package gets its own.
        context = Context()

        return Module(name: moduleName, context: context)
    }()

    lazy var builder: IRBuilder = {
        return IRBuilder(module: module)
    }()
    lazy var passManager: FunctionPassManager = {
        let pm = FunctionPassManager(module: module)

        let optLevel = compiler.options.optimizationLevel
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

        if let existing = compiler.packages[fullpath] {
            return existing
        }

        let package = SourcePackage(files: [], fullpath: fullpath, pathImportedAs: fullpath, importedFrom: importedFrom)
        sourceFilesInDir(fullpath).forEach {
            // Adds to package
            let sourceFile = SourceFile.new(path: fullpath + "/" + $0, package: package)!
            sourceFile.scope = package.scope
        }

        compiler.declare(package: package)

        return package
    }

    public static func newStubPackage(fullpath: String, importPath: String, importedFrom: SourceFile? = nil) -> SourcePackage {
        if let existing = compiler?.packages[fullpath] {
            return existing
        }

        let package = SourcePackage(files: [], fullpath: fullpath, pathImportedAs: fullpath, importedFrom: importedFrom)
        return package
    }

    public static func gatherLinkerFlags() -> Set<String> {
        var libs: Set<String> = []

        for (_, package) in compiler.packages {
            for lib in package.linkedLibraries {
                libs.insert(lib)
            }
        }

        return libs
    }
}

extension SourcePackage {

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
        guard !emitted else {
            return
        }
        emitted = true
        let startTime = gettime()

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

        let endTime = gettime()
        let totalTime = endTime - startTime
        emitStageTiming += totalTime
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
