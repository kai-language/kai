
import Foundation

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

    var pathFirstImportedAs: String
    var imports: [Import] = []

    var cost: UInt? = nil

    lazy var checker: Checker = {
        return Checker(file: self)
    }()

    // Set in Checker
    var scope: Scope

    // Set in IRGen lazily
    lazy var irContext: IRGenerator.Context = {
        let packagePrefix = package.isInitialPackage ? "" : package.moduleName
        let filePrefix = isInitialFile ? "" : dropExtension(path: pathFirstImportedAs)
        
        return IRGenerator.Context(mangledNamePrefix: packagePrefix + filePrefix, deferBlocks: [], returnBlock: nil, previous: nil)
    }()

    init(handle: FileHandle, fullpath: String, pathImportedAs: String, importedFrom: SourceFile?, package: SourcePackage) {
        self.package = package
        self.handle = handle
        self.fullpath = fullpath
        self.pathFirstImportedAs = pathImportedAs
        self.firstImportedFrom = importedFrom
        self.size = UInt32(handle.seekToEndOfFile())

        self.fileno = package.fileno
        self.scope = Scope(parent: Scope.global, isFile: true)
        package.fileno += 1
        handle.seek(toFileOffset: 0)
    }

    /// - Returns: nil iff the file could not be located or opened for reading
    public static func new(path: String, package: SourcePackage, importedFrom: SourceFile? = nil, firstFile: Bool = false) -> SourceFile? {

        var pathRelativeToInitialFile = path

        if let importedFrom = importedFrom {
            pathRelativeToInitialFile = dirname(path: importedFrom.fullpath) + path
        }

        guard let fullpath = realpath(relpath: pathRelativeToInitialFile) else {
            return nil
        }

        if !firstFile, let existing = compiler.files[fullpath] {
            return existing
        }

        guard let handle = FileHandle(forReadingAtPath: fullpath) else {
            return nil
        }

        let sourceFile = SourceFile(handle: handle, fullpath: fullpath, pathImportedAs: path, importedFrom: importedFrom, package: package)
        package.files.append(sourceFile)

        return sourceFile
    }

    public static func new(fullpath: String, importPath: String, package: SourcePackage) -> SourceFile {
        guard let handle = FileHandle(forReadingAtPath: fullpath) else {
            fatalError("Failed to open file at path \(fullpath)")
        }

        let file = SourceFile(handle: handle, fullpath: fullpath, pathImportedAs: importPath, importedFrom: nil, package: package)
        package.files.append(file)

        return file
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
                i.importee = dependency
                self.package.dependencies.append(dependency)

                i.scope = dependency.scope

                for file in dependency.files {
                    compiler.declare(file: file)
                }
            } else {
                guard let file = SourceFile.new(path: path, package: package, importedFrom: importedFrom) else {
                    preconditionFailure()
                }
                i.importee = file
                i.scope = file.scope

                compiler.declare(file: file)
            }
        case let call as Call where (call.fun as? Ident)?.name == "kai":
            guard call.args.count >= 1 else {
                addError("Expected 1 or more arguments", call.lparen)
                return
            }
            guard let lit = call.args[0] as? BasicLit, let repo = lit.constant as? String else {
                addError("Expected string literal representing github user/repo", call.args[0].start)
                return
            }
            #if DEVELOPER
            if let basedir = ProcessInfo.processInfo.environment["KAISTDLIB"] {
                let dependency = SourcePackage.new(fullpath: basedir + repo, importedFrom: importedFrom)!
                i.importee = dependency
                i.scope = dependency.scope
                i.resolvedName = repo
                compiler.declare(package: dependency)
                self.package.dependencies.append(dependency)
            } else {
                addRemoteGithubPackage(user: "kai-language", repo: repo, import: i, importedFrom: importedFrom)
            }
            #else
            addRemoteGithubPackage(user: "kai-language", repo: repo, import: i, importedFrom: importedFrom)
            #endif

        case let call as Call where (call.fun as? Ident)?.name == "github":
            guard call.args.count >= 1 else {
                addError("Expected 1 or more arguments", call.lparen)
                return
            }

            guard let lit = call.args[0] as? BasicLit, let userRepo = lit.constant as? String else {
                addError("Expected string literal representing github user/repo", call.args[0].start)
                return
            }

            let split = userRepo.split(separator: "/")
            guard split.count == 2 else {
                addError("Expected string literal of the form user/repo", lit.start)
                return
            }

            let (user, repo) = (String(split[0]), String(split[1]))
            addRemoteGithubPackage(user: user, repo: repo, import: i, importedFrom: importedFrom)

        default:
            addError("Expected import path as string", i.path.start)
            return
        }
    }

    /// - Returns: A Package which will later be fulfilled
    func addRemoteGithubPackage(user: String, repo: String, import i: Import, importedFrom: SourceFile) {
        let packageDirectory = dependencyPath + "/" + user + "/" + repo

        let dependency = SourcePackage.newStubPackage(fullpath: packageDirectory, importPath: "git(\"github.com/\(user)/\(repo)", importedFrom: self)
        i.importee = dependency
        i.scope = dependency.scope
        i.resolvedName = pathToEntityName(packageDirectory)
        if !isDirectory(path: packageDirectory) {

            let cloneJob = Job.clone(fullpath: packageDirectory, work: {
                print("Cloning \(user)/\(repo)...")
                Git().clone(repo: "https://github.com/" + user + "/" + repo + ".git", to: packageDirectory)

                sourceFilesInDir(packageDirectory).forEach {
                    // Adds to package
                    let sourceFile = SourceFile.new(path: packageDirectory + "/" + $0, package: dependency)!
                    sourceFile.scope = dependency.scope
                }
                self.package.dependencies.append(dependency)

                compiler.declare(package: dependency)
            })

            compiler.declare(job: cloneJob)
        } else { // Directory exists already

            sourceFilesInDir(packageDirectory).forEach {
                // Adds to package
                let sourceFile = SourceFile.new(path: packageDirectory + "/" + $0, package: dependency)!
                sourceFile.scope = dependency.scope
            }
            self.package.dependencies.append(dependency)

            compiler.declare(package: dependency)
        }
    }
}

extension SourceFile {
    public func parse() {
        let startTime = gettime()

        var parser = Parser(file: self)
        self.nodes = parser.parseFile()

        let endTime = gettime()
        let totalTime = endTime - startTime
        parseStageTiming += totalTime
    }

    public func collect() {
        let startTime = gettime()

        checker.collectFile()
        let endTime = gettime()
        let totalTime = endTime - startTime
        collectStageTiming += totalTime
    }

    public func check() {
        let startTime = gettime()

        var checker = Checker(file: self)
        checker.checkFile()

        let endTime = gettime()
        let totalTime = endTime - startTime
        checkStageTiming += totalTime
    }

    public func generateIntermediateRepresentation() {
        let startTime = gettime()

        var irGenerator = IRGenerator(
            topLevelNodes: nodes,
            package: package,
            context: irContext,
            isInvokationFile: isInitialFile,
            isModuleDependency: !package.isInitialPackage
        )
        irGenerator.emit()

        let endTime = gettime()
        let totalTime = endTime - startTime
        irgenStageTiming += totalTime
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
//        assert(pos.offset <= size)
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
        wasError = true
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

extension SourceFile: Hashable {
    public var hashValue: Int {
        return unsafeBitCast(self, to: Int.self)
    }

    public static func ==(lhs: SourceFile, rhs: SourceFile) -> Bool {
        return lhs === rhs
    }
}
