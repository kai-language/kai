
import Foundation

public var threadPool: ThreadPool!

final class WorkerThread: Thread {
    unowned var pool: ThreadPool
    var isIdle: Bool = true

    init(pool: ThreadPool) {
        self.pool = pool
    }

    override func main() {
        while true {
            pool.mutex.lock()
            let isJobs = !pool.ready.isEmpty
            if isJobs {
                isIdle = false
                let job = pool.ready.removeLast()
                pool.mutex.unlock()
                if Options.instance.flags.contains(.emitDebugTimes) {
                    job.startTime = gettime()
                }
                job.work()
                if Options.instance.flags.contains(.emitDebugTimes) {
                    timingMutex.lock()
                    let endTime = gettime()
                    debugTimings.append((name: job.name, duration: endTime - job.startTime))
                    timingMutex.unlock()
                }
                for dependent in job.dependents {
                    pool.add(job: dependent)
                }
            } else {
                isIdle = true
                pool.mutex.unlock()
                usleep(1)
            }
        }
    }
}

public final class ThreadPool {

    let mutex = Mutex()
    var ready: [Job] = []

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
        ready.append(job)
        mutex.unlock()
    }

    public func waitUntilDone() {
        while !ready.isEmpty || !threads.reduce(true, { $0 && $1.isIdle }) {
            usleep(1)
        }
    }
}

final class Job {

    var name: String
    var work: () -> Void
    var startTime = 0.0

    var dependents: [Job] = []

    init(_ name: String, work: @escaping () -> Void) {
        self.name = name
        self.work = work
    }

    func start() {
        startTime = gettime()
    }

    func end() {
        
    }

    func addDependent(_ job: Job) {
        dependents.append(job)
    }
}
