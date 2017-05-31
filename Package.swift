import PackageDescription

let package = Package(
  name: "kai",
  dependencies: [
    .Package(url: "https://github.com/vapor/console.git", majorVersion: 1),
    .Package(url: "https://github.com/vdka/LLVMSwift.git", majorVersion: 0, minor: 2),
    .Package(url: "https://github.com/vdka/ByteHashable.git", majorVersion: 1),
    .Package(url: "https://github.com/vdka/OrderedDictionary.git", majorVersion: 1),
  ]
)
