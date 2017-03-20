
import Darwin

func gettime() -> Double {

    var tv = timeval()
    gettimeofday(&tv, nil)

    return Double(tv.tv_sec) + Double(tv.tv_usec) / 1000000
}


fileprivate var currentTiming: (name: String, start: Double)?
var timings: [(name: String, duration: Double)] = []

// TODO(vdka): Support multithreading
func startTiming(_ name: String) {
    let currTime = gettime()

    guard let lastTiming = currentTiming else {
        currentTiming = (name, currTime)
        return
    }

    let duration = currTime - lastTiming.start
    timings.append((lastTiming.name, duration))

    currentTiming = (name, currTime)
}

func endTiming() {
    let currTime = gettime()

    guard let lastTiming = currentTiming else {
        panic() // You called endTiming without any activing timing.
    }

    let duration = currTime - lastTiming.start
    timings.append((lastTiming.name, duration))

    currentTiming = nil
}

func measure<R>(_ closure: () throws -> R) rethrows -> (R, Double) {

    let begin = gettime()

    let result = try closure()

    let end = gettime()

    return (result, end - begin)
}
