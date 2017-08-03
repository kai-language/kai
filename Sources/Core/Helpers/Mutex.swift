
import Darwin

/// A basic wrapper around the "NORMAL" `pthread_mutex_t` (a safe, general purpose FIFO mutex). This type is a "class" type to take advantage of the "deinit" method and prevent accidental copying of the `pthread_mutex_t`.
final class Mutex {
    typealias MutexPrimitive = pthread_mutex_t

    var unsafeMutex = pthread_mutex_t()

    /// Default constructs as ".Normal" or ".Recursive" on request.
    init() {
        var attr = pthread_mutexattr_t()
        guard pthread_mutexattr_init(&attr) == 0 else {
            preconditionFailure()
        }
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL)
        guard pthread_mutex_init(&unsafeMutex, &attr) == 0 else {
            preconditionFailure()
        }
    }

    deinit {
        pthread_mutex_destroy(&unsafeMutex)
    }

    func lock() {
        pthread_mutex_lock(&unsafeMutex)
    }

    func tryLock() -> Bool {
        return pthread_mutex_trylock(&unsafeMutex) == 0
    }

    func unlock() {
        pthread_mutex_unlock(&unsafeMutex)
    }

    func sync<R>(execute work: () throws -> R) rethrows -> R {
        pthread_mutex_lock(&unsafeMutex)
        defer { pthread_mutex_unlock(&unsafeMutex) }
        return try work()
    }
}
