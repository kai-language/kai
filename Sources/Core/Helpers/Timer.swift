
import Darwin

public func gettime() -> Double {

    var tv = timeval()
    gettimeofday(&tv, nil)

    return Double(tv.tv_sec) + Double(tv.tv_usec) / 1000000
}

public var startTime: Double = 0.0

var timingMutex = Mutex()
fileprivate var currentTiming: (name: String, start: Double)?
/// Wall time from first in stage to last in stage
public var parseStageTiming: Double = 0.0
public var collectStageTiming: Double = 0.0
public var checkStageTiming: Double = 0.0
public var irgenStageTiming: Double = 0.0

/// Thread time per file
public var debugTimings: [(name: String, duration: Double)] = []

extension Double {

    public var humanReadableTime: String {

        let ns = 1_000_000_000.0
        let μs = 1_000_000.0
        let ms = 1_000.0

        if self > (1 / ms) {
            return String(format: "%.0f", self * ms) + "ms"
        }
        if self > (1 / μs) {
            return String(format: "%.0f", self * μs) + "μs"
        }
        if self > (1 / ns) {
            return String(format: "%.0f", self * ns) + "ns"
        }
        return String(format: "%.0f", self) + "s"
    }
}
