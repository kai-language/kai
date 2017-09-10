
import Foundation
import Core

guard CommandLine.arguments.count > 1 else {
    print("ERROR: No input file")
    exit(1)
}

startTime = gettime()

let opts = Options(arguments: CommandLine.arguments[1...])
Options.instance = opts // Note: You must set this, it is used internally

threadPool = ThreadPool(nThreads: Options.instance.jobs)

let filepath = CommandLine.arguments.last!
guard let package = SourcePackage.makeInitial(for: filepath) else {
    print("ERROR: No such file or directory '\(filepath)'")
    exit(1)
}

package.begin()

threadPool.waitUntilDone()

if wasErrors {
    exit(1)
}

package.validateIR()

performEmissionPreflightChecks()
if opts.flags.intersection([.emitIr, .emitBitcode, .emitAssembly]).isEmpty {

    package.emitObjects()
    package.linkObjects()
    package.cleanupBuildProducts()
} else {
    if opts.flags.contains(.emitIr) {
        package.emitIntermediateRepresentation()
    }

    if opts.flags.contains(.emitBitcode) {
        package.emitBitcode()
    }

    if opts.flags.contains(.emitAssembly) {
        package.emitAssembly()
    }
}

if opts.flags.contains(.dumpIr) {
    package.dumpIntermediateRepresentation()
}

if opts.flags.contains(.emitTimes) {
    let endTime = gettime()
    let total = endTime - startTime
    print("Total time was \(total.humanReadableTime)")
}

if opts.flags.contains(.emitTimes) {
    print("Parsing took \(parseStageTiming.humanReadableTime)")
    print("Checking took \(checkStageTiming.humanReadableTime)")
    print("IRGeneration took \(irgenStageTiming.humanReadableTime)")
}

if opts.flags.contains(.emitDebugTimes) {
    for (name, duration) in debugTimings.sorted(by: { $0.name < $1.name }) {
        print("\(name) took \(duration.humanReadableTime)")
    }
}
