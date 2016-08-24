import PackageDescription

let package = Package(
  name: "kai",
  dependencies: [
    .Package(url: "https://github.com/vdka/ByteHashable.git", majorVersion: 1),
  ]
)
