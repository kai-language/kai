
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
            // check if any jobs have become unblocked and shift them into the ready pool
            for (index, job) in pool.blocked.enumerated().reversed() {
                if !job.isBlocked() {
                    pool.blocked.remove(at: index)
                    pool.ready.append(job)
                }
            }
            let isJobs = !pool.ready.isEmpty
            if isJobs {
                isIdle = false
                let job = pool.ready.removeLast()
                pool.mutex.unlock()

                job.start()
                job.work()
                job.end()

                pool.mutex.lock()
                for dependent in job.blocking {
                    pool.add(job: dependent)
                }
                pool.mutex.unlock()
            } else {
                isIdle = true
                pool.mutex.unlock()
                usleep(1)
            }
        }
    }
}

// sourcery:noinit
public final class ThreadPool {

    let mutex = Mutex()
    var ready: [Job] = []
    var blocked: [Job] = []

    var threads: [WorkerThread]

    public init(nThreads: Int) {
        self.threads = []

        for _ in 0..<nThreads {
            let thread = WorkerThread(pool: self)
            threads.append(thread)
            thread.start()
        }
    }

    func add(job: Job) {
        mutex.lock()
        if !job.isBlocked() {
            ready.append(job)
        } else {
            blocked.append(job)
        }
        mutex.unlock()
    }

    public func waitUntilDone() {
        while !ready.isEmpty || !threads.reduce(true, { $0 && $1.isIdle }) {
            usleep(1)
        }
    }
}

// sourcery:noinit
final class Job {

    var name: String
    var done: Bool = false
    var work: () -> Void
    var startTime = 0.0

    var blocking: [Job] = []
    var blockedBy: [Job] = []

    init(_ name: String, work: @escaping () -> Void) {
        self.name = name
        self.work = work
    }

    func start() {
        if Options.instance.flags.contains(.emitDebugTimes) {
            startTime = gettime()
        }
    }

    func isBlocked() -> Bool {
        blockedBy = blockedBy.filter({ !$0.done })
        return !blockedBy.isEmpty
    }

    func end() {
        if Options.instance.flags.contains(.emitDebugTimes) {
            timingMutex.lock()
            let endTime = gettime()
            debugTimings.append((name: name, duration: endTime - startTime))
            done = true
            timingMutex.unlock()
        }
    }

    func addBlocking(_ job: Job) {
        blocking.append(job)
    }

    func addBlockedBy(_ job: Job) {
        blockedBy.append(job)
    }
}
