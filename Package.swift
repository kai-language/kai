// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "kai",
    dependencies: [
        .package(url: "https://github.com/vdka/LLVMSwift.git", .branch("master")),
        .package(url: "https://github.com/BrettRToomey/CLibGit2.git", .branch("master"))
    ],
    targets: [
        .target(name: "kai", dependencies: ["Core"]),
        .target(name: "Core", dependencies: ["LLVM"]),
    ],
    swiftLanguageVersions: [4]
)
