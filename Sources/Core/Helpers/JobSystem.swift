
// sourcery:noinit
final class Job: Hashable, CustomStringConvertible {

    /// The (file/folder) path this job is associated with
    var fullpath: String
    var kind: Kind
    var done: Bool = false
    var work: () -> Void
    var startTime = 0.0

    // by default the cost is 1
    var cost: UInt = 1

    // by default jobs are not blocked
    var isBlocked: () -> Bool = { return false }

    private init(fullpath: String, kind: Kind, work: @escaping () -> Void) {
        self.fullpath = fullpath
        self.kind = kind
        self.work = work
    }

    var hashValue: Int {
        return (kind.rawValue + fullpath).hashValue
    }

    static func ==(lhs: Job, rhs: Job) -> Bool {
        return (lhs.kind.rawValue + lhs.fullpath) == (rhs.kind.rawValue + rhs.fullpath)
    }

    func start() {
        if Options.instance.flags.contains(.emitDebugTimes) {
            startTime = gettime()
        }
    }

    func finish() {
        if Options.instance.flags.contains(.emitDebugTimes) {
            let endTime = gettime()
            debugTimings.append((name: kind.rawValue + " " + fullpath, duration: endTime - startTime))
        }

        done = true
    }

    var description: String {
        return fullpath + " " + kind.rawValue
    }

    enum Kind: String {
        case cloning
        case parsing
        case collecting
        case checking
        case generating
    }
}

extension Job {

    static func clone(fullpath: String, work: @escaping () -> Void) -> Job {
        if let existing = compiler.jobs[Kind.cloning.rawValue + fullpath] {
            return existing
        }

        let job = Job(fullpath: fullpath, kind: .cloning, work: work)
        // cloning jobs have the lowest cost and are unblockable
        job.cost = 0

        compiler.jobs[job.kind.rawValue + job.fullpath] = job
        return job
    }

    static func parse(file: SourceFile) -> Job {
        if let existing = compiler.jobs[Kind.parsing.rawValue + file.fullpath] {
            return existing
        }

        let job = Job(fullpath: file.fullpath, kind: .parsing, work: file.parseEmittingErrors)
        // parsing jobs have a cost of 1 and are unblockable
        job.cost = 1

        compiler.jobs[job.kind.rawValue + job.fullpath] = job
        return job
    }

    static func collect(file: SourceFile) -> Job {
        if let existing = compiler.jobs[Kind.collecting.rawValue + file.fullpath] {
            return existing
        }

        let job = Job(fullpath: file.fullpath, kind: .collecting, work: file.collect)
        // collecting jobs have a cost of 1 and are unblockable
        job.cost = 2

        compiler.jobs[job.kind.rawValue + job.fullpath] = job
        return job
    }

    static func check(file: SourceFile) -> Job {
        if let existing = compiler.jobs[Kind.checking.rawValue + file.fullpath] {
            return existing
        }

        let job = Job(fullpath: file.fullpath, kind: .checking, work: file.checkEmittingErrors)

        job.cost = file.cost!

        compiler.jobs[job.kind.rawValue + job.fullpath] = job
        return job
    }

    static func generate(package: SourcePackage) -> Job {
        if let existing = compiler.jobs[Kind.generating.rawValue + package.fullpath] {
            return existing
        }

        let job = Job(fullpath: package.fullpath, kind: .generating, work: { package.files.forEach({ $0.generateIntermediateRepresentation() }) })

        compiler.jobs[job.kind.rawValue + job.fullpath] = job
        return job
    }
}
