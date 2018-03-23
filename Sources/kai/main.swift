
import Foundation
import Core

guard CommandLine.arguments.count > 1 else {
    print("ERROR: No input file")
    exit(1)
}

startTime = gettime()

let opts = Options(arguments: CommandLine.arguments[1...])

setupTargetMachine(targetTriple: opts.target)

let filepath = CommandLine.arguments.last!

compiler = Compiler(invokePath: filepath, options: opts)
guard compiler != nil else {
    print("ERROR: \(filepath) was invalid!")
    exit(1)
}

compiler.run()

if wasError {
    exit(1)
}

compiler.initialPackage.validateIR()

setupBuildDirectories()

if opts.flags.intersection([.emitIr, .emitBitcode, .emitAssembly]).isEmpty {

    compiler.emitObjects()
    compiler.linkObjects()
    if !opts.flags.contains(.noCleanup) {
        compiler.cleanupBuildProducts()
    }
} else {
    if opts.flags.contains(.emitIr) {
        compiler.emitIntermediateRepresentation()
    }

    if opts.flags.contains(.emitBitcode) {
        compiler.emitBitcode()
    }

    if opts.flags.contains(.emitAssembly) {
        compiler.emitAssembly()
    }
}

if opts.flags.contains(.dumpIr) {
    compiler.dumpIntermediateRepresentation()
}

if opts.flags.contains(.emitDebugTimes) {
    for (name, duration) in debugTimings.sorted(by: { $0.name < $1.name }) {
        print("\(name) took \(duration.humanReadableTime)")
    }
}

if opts.flags.contains(.emitTimes) {
    print("Parsing took \(parseStageTiming.humanReadableTime)")
    print("Collecting took \(collectStageTiming.humanReadableTime)")
    print("Checking took \(checkStageTiming.humanReadableTime)")
    print("IRGeneration took \(irgenStageTiming.humanReadableTime)")
    print("Emitting Object Files took \(emitStageTiming.humanReadableTime)")
    print("Linking Object Files took \(linkStageTiming.humanReadableTime)")

    let endTime = gettime()
    let total = endTime - startTime
    print("Total time was \(total.humanReadableTime)")
}
