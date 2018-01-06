
import Foundation

public var compiler: Compiler!

// sourcery: noinit
public class Compiler {

    /// - Note: Returns nil iff the invokePath is invalid
    public init?(invokePath: String, options: Options) {
        guard let fullpath = realpath(relpath: invokePath) else {
            return nil
        }

        self.initialPackage = SourcePackage(files: [], fullpath: fullpath, pathImportedAs: invokePath, importedFrom: nil)
        self.initialFile = SourceFile.new(fullpath: fullpath, importPath: invokePath, package: initialPackage)
        self.options = options
    }

    public var options: Options
    public var initialFile: SourceFile
    public var initialPackage: SourcePackage

#if os(Linux)
    public static var isLinux = true
    public static var isMac = false
#elseif os(macOS)
    public static var isLinux = false
    public static var isMac = true
#else
    public static var isLinux = false
    public static var isMac = false
#endif

    var generatedPackage = SourcePackage.newStubPackage(fullpath: buildDirectory + "/generated", importPath: "")

    var packages: [String: SourcePackage] = [:]
    var files: [String: SourceFile] = [:]
    var jobs: [String: Job] = [:]

    var specializations: [FunctionSpecialization] = []

    var costs: [SourceFile: Int] = [:]

    /// Cloning, Parsing, Collecting, costs are set in that order.
    var cloneParseCollectQueue = PriorityQueue<Job>(sort: { $0.cost < $1.cost })
    var checkingQueue = PriorityQueue<Job>(sort: { $0.cost < $1.cost })
    var generationQueue = Queue<Job>()

    public func run() {
        self.declare(package: initialPackage)

        while let job = cloneParseCollectQueue.dequeue() {
            let startTime = gettime()
            job.work()
            let endTime = gettime()
            debugTimings.append((job.description, endTime - startTime))
        }

        guard !wasError else {
            for file in files.values {
                emitErrors(for: file, at: "Parsing")
            }
            return
        }

        // All cloning, parsing, and collecting has been completed.
        self.evaluateCheckingCosts()

        for file in files.values {
            let checkingJob = Job.check(file: file)
            checkingQueue.enqueue(checkingJob)
        }

        // For IRGen each package may be generated in it's own thread
        for package in packages.values {
            let generationJob = Job.generate(package: package)
            generationQueue.enqueue(generationJob)
        }

        while let job = checkingQueue.dequeue() {
            let startTime = gettime()
            job.work()
            let endTime = gettime()
            debugTimings.append((job.description, endTime - startTime))
        }
        
        guard !wasError else {
            for file in files.values {
                emitErrors(for: file, at: "Parsing")
            }
            return
        }

        if !specializations.isEmpty {
            var gen = IRGenerator(specializations: specializations, package: generatedPackage)
            gen.emit()
        }

        while let job = generationQueue.dequeue() {
            let startTime = gettime()
            job.work()
            let endTime = gettime()
            debugTimings.append((job.description, endTime - startTime))
        }
    }

    func evaluateCheckingCosts() {

        func assignCost(forImport i: Importable) -> UInt {
            if let existing = i.cost {
                return existing
            }

            // Set this so that we can cost circular imports
            i.cost = 1

            var cost: UInt
            switch i {
            case let file as SourceFile:
                cost = file.importees.reduce(0, { max($0, assignCost(forImport: $1)) }) + 1
            case let package as SourcePackage:
                cost = package.importees.reduce(0, { max($0, assignCost(forImport: $1)) }) + 1
            default:
                fatalError()
            }
            i.cost = cost
            return cost
        }

        initialFile.cost = initialFile.importees.reduce(0, { max($0, assignCost(forImport: $1)) }) + 1
    }

    public func validateIR() {
        generatedPackage.validateIR()
        initialPackage.validateIR()
    }

    public func emitObjects() {
        initialPackage.dependencies.append(generatedPackage)
        initialPackage.emitObjects()
    }

    public func emitIntermediateRepresentation() {
        generatedPackage.emitIntermediateRepresentation()
        initialPackage.emitIntermediateRepresentation()
    }

    public func emitBitcode() {
        generatedPackage.emitBitcode()
        initialPackage.emitBitcode()
    }

    public func emitAssembly() {
        generatedPackage.emitAssembly()
        initialPackage.emitAssembly()
    }

    public func dumpIntermediateRepresentation() {
        generatedPackage.dumpIntermediateRepresentation()
        initialPackage.dumpIntermediateRepresentation()
    }

    public func linkObjects() {
        let startTime = gettime()
        let clangPath = getClangPath()

        let objFilePaths = packages.values.map({ $0.objpath })
        var args = ["-o", options.outputFile ?? initialPackage.moduleName] + objFilePaths + [generatedPackage.objpath]

        if compiler.options.flags.contains(.shared) {
            args.append("-shared")
        } else if compiler.options.flags.contains(.dynamicLib) {
            args.append("-dynamiclib")
        }

        let allLinkedLibraries = packages.values.reduce(Set(), { $0.union($1.linkedLibraries) })
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

        let endTime = gettime()
        let totalTime = endTime - startTime
        linkStageTiming += totalTime
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

extension Compiler {

    /// Creates all needed jobs to start processing the file.
    func declare(file: SourceFile) {
        guard !files.keys.contains(file.fullpath) else {
            return
        }

        files[file.fullpath] = file

        let parsingJob = Job.parse(file: file)
        declare(job: parsingJob)

        let collectingJob = Job.collect(file: file)
        declare(job: collectingJob)
    }

    func declare(package: SourcePackage) {
        guard !packages.keys.contains(package.fullpath) else {
            return
        }
//        print("Found package \(package.pathFirstImportedAs)")

        packages[package.fullpath] = package

        for file in package.files {
            declare(file: file)
        }
    }

    func declare(job: Job) {
//        print("Declaring job \(job.kind) \(job.fullpath)")

        switch job.kind {
        case .cloning, .parsing, .collecting:
            cloneParseCollectQueue.enqueue(job)
        case .checking:
            checkingQueue.enqueue(job)
        case .generating:
            generationQueue.enqueue(job)
        }
    }
}

protocol Importable: class {
    var importees: [Importable] { get }
    var cost: UInt? { get set }
}

extension SourcePackage: Importable {
    var importees: [Importable] {
        return files
    }
}

extension SourceFile: Importable {
    var importees: [Importable] {
        return imports.map { i in
            return i.importee
        }
    }
}
