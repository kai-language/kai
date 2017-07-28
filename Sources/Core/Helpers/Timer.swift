
import Darwin

func gettime() -> Double {

    var tv = timeval()
    gettimeofday(&tv, nil)

    return Double(tv.tv_sec) + Double(tv.tv_usec) / 1000000
}


fileprivate var currentTiming: (name: String, start: Double)?
public var timings: [(name: String, duration: Double)] = []

// TODO(vdka): Support multithreading
public func startTiming(_ name: String) {
    let currTime = gettime()

    guard let lastTiming = currentTiming else {
        currentTiming = (name, currTime)
        return
    }

    let duration = currTime - lastTiming.start
    timings.append((lastTiming.name, duration))

    currentTiming = (name, currTime)
}

public func endTiming() {
    let currTime = gettime()

    guard let lastTiming = currentTiming else {
        fatalError()
    }

    let duration = currTime - lastTiming.start
    timings.append((lastTiming.name, duration))

    currentTiming = nil
}
