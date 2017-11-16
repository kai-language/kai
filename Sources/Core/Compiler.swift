
public var compiler: Compiler!

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

    var packages: [String: SourcePackage] = [:]
    var files: [String: SourceFile] = [:]
    var jobs: [String: Job] = [:]

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
