
import Foundation

var knownSourceFiles: [String: SourceFile] = [:]

// sourcery:noinit
public final class SourceFile {

    unowned var package: SourcePackage

    weak var firstImportedFrom: SourceFile?
    var isInitialFile: Bool {
        return firstImportedFrom == nil
    }

    /// The base offset for this file
    var fileno: UInt32
    var size: UInt32
    var lineOffsets: [UInt32] = [0]
    var linesOfSource: Int = 0

    var errors: [SourceError] = []
    var notes: [Int: [String]] = [:]

    var nodes: [TopLevelStmt] = []

    var handle: FileHandle
    var fullpath: String

    var stage: String = ""
    var hasBeenParsed: Bool = false
    var hasBeenChecked: Bool = false
    var hasBeenGenerated: Bool = false

    var pathFirstImportedAs: String
    var imports: [Import] = []

    var parsingJob: Job!
    var checkingJob: Job!
    var generationJob: Job!

    // Set in Checker
    var scope: Scope

    init(handle: FileHandle, fullpath: String, pathImportedAs: String, importedFrom: SourceFile?, package: SourcePackage) {
        self.package = package
        self.handle = handle
        self.fullpath = fullpath
        self.pathFirstImportedAs = pathImportedAs
        self.firstImportedFrom = importedFrom
        self.size = UInt32(handle.seekToEndOfFile())

        package.filenoMutex.lock()
        self.fileno = package.fileno
        self.scope = Scope(parent: Scope.global, isFile: true)
        package.fileno += 1
        package.filenoMutex.unlock()
        handle.seek(toFileOffset: 0)
    }

    /// - Returns: nil iff the file could not be located or opened for reading
    public static func new(path: String, package: SourcePackage, importedFrom: SourceFile? = nil) -> SourceFile? {

        var pathRelativeToInitialFile = path

        if let importedFrom = importedFrom {
            pathRelativeToInitialFile = dirname(path: importedFrom.fullpath) + path
        }

        guard let fullpath = realpath(relpath: pathRelativeToInitialFile) else {
            return nil
        }

        if let existing = knownSourceFiles[fullpath] {
            return existing
        }

        guard let handle = FileHandle(forReadingAtPath: fullpath) else {
            return nil
        }

        let sourceFile = SourceFile(handle: handle, fullpath: fullpath, pathImportedAs: path, importedFrom: importedFrom, package: package)
        package.files.append(sourceFile)

        let parsingJob = Job("\(path) - Parsing", work: sourceFile.parseEmittingErrors)
        let checkingJob = Job("\(path) - Checking", work: sourceFile.checkEmittingErrors)
        let generationJob = Job("\(path) - Generating IR", work: sourceFile.generateIntermediateRepresentation)

        generationJob.addDependency(checkingJob)
        checkingJob.addDependency(parsingJob)

        sourceFile.parsingJob = parsingJob
        sourceFile.checkingJob = checkingJob
        sourceFile.generationJob = generationJob

        knownSourceFiles[fullpath] = sourceFile

        return sourceFile
    }
}

extension SourceFile {

    func add(import i: Import, importedFrom: SourceFile) {
        imports.append(i)

        switch i.path {
        case let lit as BasicLit where lit.token == .string:
            let path = lit.constant as! String

            let relpath = dirname(path: importedFrom.fullpath) + path
            guard let fullpath = realpath(relpath: relpath) else {
                addError("Failed to open '\(path)'", lit.start)
                return
            }

            i.resolvedName = i.alias?.name ?? pathToEntityName(path)
            if isDirectory(path: fullpath) {
                guard let dependency = SourcePackage.new(relpath: path, importedFrom: self) else {
                    preconditionFailure()
                }
                self.package.dependencies.append(dependency)
                dependency.begin()

                i.scope = dependency.scope

                for file in dependency.files {
                    importedFrom.checkingJob.addDependency(file.checkingJob)
                    importedFrom.generationJob.addDependency(file.generationJob)
                    threadPool.add(job: file.parsingJob)
                }
            } else {
                guard let file = SourceFile.new(path: path, package: package, importedFrom: importedFrom) else {
                    preconditionFailure()
                }
                i.scope = file.scope

                importedFrom.checkingJob.addDependency(file.checkingJob)
                importedFrom.generationJob.addDependency(file.generationJob)
                threadPool.add(job: file.parsingJob)
            }

        case let call as Call where (call.fun as? Ident)?.name == "github":

            guard call.args.count >= 1 else {
                addError("Expected 1 or more arguments", call.lparen)
                return
            }

            guard let lit = call.args[0] as? BasicLit, lit.token == .string else {
                addError("Expected string literal representing github user/repo", call.args[0].start)
                return
            }
            let userRepo = lit.constant as! String

            let split = userRepo.split(separator: "/")
            guard split.count == 2 else {
                addError("Expected string literal of the form user/repo", lit.start)
                return
            }

            let (user, repo) = (split[0], split[1])

            let packageDirectory = dirname(path: importedFrom.package.fullpath) + "deps/github/" + user + "/" + repo

            i.resolvedName = pathToEntityName(packageDirectory)
            if !isDirectory(path: packageDirectory) {

                let job = Job(repo + "/" + user + " - Cloning", work: {
                    cloneMutex.lock()
                    cloneQueue.removeFirst()
                    Git().clone(repo: "https://github.com/" + user + "/" + repo + ".git", to: packageDirectory)
                    cloneMutex.unlock()

                    guard let dependency = SourcePackage.new(fullpath: packageDirectory, importedFrom: self) else {
                        preconditionFailure()
                    }
                    self.package.dependencies.append(dependency)
                    dependency.begin()

                    i.scope = dependency.scope
                })

                cloneMutex.lock()
                // TODO: What is going on here?
                if let last = cloneQueue.last {
                    last.addDependency(job)
                    cloneQueue.append(job)
                } else {
                    cloneQueue.append(job)
                    threadPool.add(job: job)
                }
                cloneMutex.unlock()
            } else { // Directory exists already

                guard let dependency = SourcePackage.new(fullpath: packageDirectory, importedFrom: self) else {
                    preconditionFailure()
                }
                self.package.dependencies.append(dependency)
                dependency.begin()

                i.scope = dependency.scope
            }

        default:
            addError("Expected import path as string", i.path.start)
            return
        }
    }
}

extension SourceFile {
    public func parseEmittingErrors() {
        assert(!hasBeenParsed)
        let startTime = gettime()

        stage = "Parsing"
        var parser = Parser(file: self)
        self.nodes = parser.parseFile()
        hasBeenParsed = true
        emitErrors(for: self, at: stage)

        if errors.count > 0 {
            // FIXME: What do?
//            parsingJob.dequeueBlocking(checkingJob)
        }

        let endTime = gettime()
        let totalTime = endTime - startTime
        timingMutex.lock()
        parseStageTiming += totalTime
        timingMutex.unlock()
    }

    public func checkEmittingErrors() {
        assert(hasBeenParsed)
        guard !hasBeenChecked else {
            return
        }
        let startTime = gettime()

        stage = "Checking"
        var checker = Checker(file: self)
        checker.check()
        hasBeenChecked = true
        emitErrors(for: self, at: stage)

        if errors.count > 0 {
            // FIXME: What do?
//            checkingJob.dequeueBlocking(generationJob)
        }

        let endTime = gettime()
        let totalTime = endTime - startTime
        timingMutex.lock()
        checkStageTiming += totalTime
        timingMutex.unlock()
    }

    public func generateIntermediateRepresentation() {
        assert(hasBeenChecked)
        assert(!hasBeenGenerated)
        let startTime = gettime()

        stage = "IRGeneration"
        var irGenerator = IRGenerator(file: self)
        irGenerator.generate()
        hasBeenGenerated = true

        let endTime = gettime()
        let totalTime = endTime - startTime
        timingMutex.lock()
        irgenStageTiming += totalTime
        timingMutex.unlock()
    }
}

extension SourceFile {

    func addLine(offset: UInt32) {
        assert(lineOffsets.count == 0 || lineOffsets.last! < offset)
        lineOffsets.append(offset)
    }

    func pos(offset: UInt32) -> Pos {
        assert(offset <= self.size)
        return Pos(fileno: fileno, offset: offset)
    }

    func offset(pos: Pos) -> UInt32 {
        assert(pos.offset <= size)
        return pos.offset
    }

    func position(for pos: Pos) -> Position {
        return unpack(offset: offset(pos: pos))
    }

    func position(forOffset offset: UInt32) -> Position {
        return unpack(offset: offset)
    }

    func unpack(offset: UInt32) -> Position {
        var line, column: UInt32
        if let firstPast = lineOffsets.enumerated().first(where: { $0.element > offset }) {
            let i = firstPast.offset - 1
            line = UInt32(i) + 1
            column = offset - lineOffsets[i] + 1
        } else {
            (line, column) = (0, 0)
        }
        return Position(filename: pathFirstImportedAs, offset: offset, line: line, column: column)
    }

    func addError(_ msg: String, _ pos: Pos) {
        let error = SourceError(pos: pos, msg: msg)
        errors.append(error)
    }

    func attachNote(_ message: String) {
        assert(!errors.isEmpty)

        guard var existingNotes = notes[errors.endIndex - 1] else {
            notes[errors.endIndex - 1] = [message]
            return
        }
        existingNotes.append(message)
        notes[errors.endIndex - 1] = existingNotes
    }
}
