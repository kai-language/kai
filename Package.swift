// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "kai",
    dependencies: [
    ],
    targets: [
        .target(name: "kai", dependencies: ["Core"]),
        .target(name: "Core", dependencies: []),
    ],
    swiftLanguageVersions: [4]
)
