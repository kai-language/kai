
import Foundation
import Core

guard CommandLine.arguments.count > 1 else {
    print("ERROR: No input file")
    exit(1)
}

startTime = gettime()

let filepath = CommandLine.arguments.last!
guard let package = SourcePackage.makeInitial(for: filepath) else {
    print("ERROR: No such file or directory '\(filepath)'")
    exit(1)
}

Options.instance = Options(arguments: CommandLine.arguments[1...])

performCompilationPreflightChecks(with: Options.instance, initialPackage: package)

threadPool = ThreadPool(nThreads: Options.instance.jobs)

package.begin()

threadPool.waitUntilDone()

SourcePackage.exportAll()

if Options.instance.flags.contains(.emitIr) {
    SourcePackage.emitAllIr()
}

if Options.instance.flags.contains(.emitTimes) {
    let endTime = gettime()
    let total = endTime - startTime
    print("Total time was \(total.humanReadableTime)")
}

if Options.instance.flags.contains(.emitTimes) {
    print("Parsing took \(parseStageTiming.humanReadableTime)")
    print("Checking took \(checkStageTiming.humanReadableTime)")
    print("IRGeneration took \(irgenStageTiming.humanReadableTime)")
}

if Options.instance.flags.contains(.emitDebugTimes) {
    for (name, duration) in debugTimings.sorted(by: { $0.name < $1.name }) {
        print("\(name) took \(duration.humanReadableTime)")
    }
}
