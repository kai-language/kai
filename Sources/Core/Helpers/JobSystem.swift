
import Foundation

public var threadPool: ThreadPool!

// sourcery:noinit
final class WorkerThread: Thread {
    unowned var pool: ThreadPool
    var isIdle: Bool = true

    init(pool: ThreadPool) {
        self.pool = pool
    }

    override func main() {
        while true {
            pool.mutex.lock()
            guard !pool.queue.isEmpty else {
                isIdle = true
                pool.mutex.unlock()
                usleep(1)
                continue
            }

            guard let (index, job) = pool.queue.enumerated().first(where: { !$0.element.isBlocked }) else {
                isIdle = true
                pool.mutex.unlock()
                usleep(1)
                continue
            }

            // Mark thread as non idle
            isIdle = false

            // remove the job from the queue
            pool.queue.remove(at: index)
            pool.mutex.unlock()

            job.start()
            job.work()
            job.finish()

            pool.totalCompleted += 1
            for dependent in job.dependents where dependent.dependencyCount < 1 {
                pool.add(job: dependent)
            }
        }
    }
}

// sourcery:noinit
public final class ThreadPool {

    let mutex = Mutex()
    var queue: [Job] = []
    var known: Set<Job> = []

    var threads: [WorkerThread]

    var totalCompleted: Int = 0

    public init(nThreads: Int) {
        self.threads = []

        for _ in 0..<nThreads {
            let thread = WorkerThread(pool: self)
            threads.append(thread)
            thread.start()
        }
    }

    func add(job: Job) {
        guard !known.contains(job) else {
            return
        }
        known.insert(job)
        mutex.lock()
        queue.append(job)
        mutex.unlock()
    }

    public func waitUntilDone() {
        while true {
            mutex.lock()
            if queue.isEmpty && threads.reduce(true, { $0 && $1.isIdle }) {
                defer {
                    mutex.unlock()
                }

                break
            }
            mutex.unlock()
            usleep(1)
        }
    }

    public func visualize() {
        print("Ready:")
        for job in queue {
            job.visualize()
        }
    }
}

var jobMutex = Mutex()
var knownJobs: [String: Job] = [:]

// sourcery:noinit
final class Job: Hashable {

    /// The (file/folder) path this job is associated with
    var fullpath: String
    var operation: String
    var done: Bool = false
    var work: () -> Void
    var startTime = 0.0

    var dependents: [Job] = []
    var dependencies: [Job] = []
    var dependencyCount: Int = 0

    private init(fullpath: String, operation: String, work: @escaping () -> Void) {
        self.fullpath = fullpath
        self.operation = operation
        self.work = work
    }

    /// Will return existing jobs that match.
    static func new(fullpath: String, operation: String, work: @escaping () -> Void) -> Job {
        if let existing = knownJobs[operation + fullpath] {
            return existing
        }

        let job = Job(fullpath: fullpath, operation: operation, work: work)
        jobMutex.lock()
        knownJobs[operation + fullpath] = job
        jobMutex.unlock()
        return job
    }

    var isBlocked: Bool {
        return dependencyCount != 0
    }

    var hashValue: Int {
        return (operation + fullpath).hashValue
    }

    static func ==(lhs: Job, rhs: Job) -> Bool {
        return (lhs.operation + lhs.fullpath) == (rhs.operation + rhs.fullpath)
    }

    func start() {
        print("Start \(operation) \(fullpath)")
        if Options.instance.flags.contains(.emitDebugTimes) {
            startTime = gettime()
        }
    }

    func finish() {
        if Options.instance.flags.contains(.emitDebugTimes) {
            timingMutex.lock()
            let endTime = gettime()
            debugTimings.append((name: operation + " " + fullpath, duration: endTime - startTime))
            timingMutex.unlock()
        }

        // NOTE: Should this be in a lock?
        for dependent in dependents {
            dependent.dependencyCount -= 1
        }

        done = true
    }

    func addDependency(_ job: Job) {
        dependencies.append(job)
        job.dependents.append(self)
        // NOTE: Should this be in a lock?
        dependencyCount += 1
    }

    public func visualize(indent: Int = 0) {
        let indentation = repeatElement("  ", count: indent).joined()
        print(indentation + fullpath + " " + operation)
        for job in dependents {
            job.visualize(indent: indent + 1)
        }
    }
}
