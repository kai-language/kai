#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Foundation
import LLVM

var targetMachine: TargetMachine!

public func setupTargetMachine() {
    do {
        targetMachine = try TargetMachine()
    } catch {
        print("ERROR: \(error)")
        print("  While setting up Target Machine")
        exit(1)
    }
}

public func setupBuildDirectories() {

    do {
        try ensureBuildDirectoriesExist()
    } catch {
        print("ERROR: \(error)")
        print("  While setting up build directories")
        exit(1)
    }
}

public func ensureBuildDirectoriesExist() throws {
    let fm = FileManager.default

    try fm.createDirectory(atPath: buildDirectory, withIntermediateDirectories: true, attributes: nil)

    for package in knownSourcePackages.values.filter({ !$0.isInitialPackage }) {
        try fm.createDirectory(atPath: dirname(path: package.emitPath), withIntermediateDirectories: true, attributes: nil)
    }
}

extension String: Swift.Error {}

// sourcery:noinit
class Ref<T> {
    var val: T
    init(_ val: T) {
        self.val = val
    }
}

extension String {

    init<T: Sequence>(_ unicodeScalars: T) where T.Element == Unicode.Scalar {
        self.init(unicodeScalars.map(Character.init))
    }

    /// This was removed from the stdlib I guess ...
    mutating func append(_ scalar: UnicodeScalar) {
        self.append(Character(scalar))
    }
}

extension BidirectionalCollection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }

    func toDictionary<Key: Hashable>(with selectKey: (Element) -> Key) -> [Key: Element] {
        var dict: [Key: Element] = [:]
        for element in self {
            dict[selectKey(element)] = element
        }
        return dict
    }
}

public func dirname(path: String) -> String {
    if !path.contains("/") {
        return "."
    }
    return String(path.reversed().drop(while: { $0 != "/" }).reversed())
}

public func basename(path: String) -> String {
    return String(path.split(separator: "/").last ?? "")
}

public func dropExtension(path: String) -> String {
    return String(path.split(separator: ".").first ?? "")
}

public func realpath(relpath: String) -> String? {
    guard let fullpathC = realpath(relpath, nil) else {
        return nil
    }

    return String(cString: fullpathC)
}

public func sourceFilesInDir(_ path: String, recurse: Bool = false) -> [String] {
    guard let dir = opendir(path) else {
        return []
    }

    var files: [String] = []
    while let p = readdir(dir) {
        var ent = p.pointee
        let name = withUnsafeBytes(of: &ent.d_name) { b in
            return String(cString: b.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        if name.hasPrefix(".") {
            continue
        }
        if ent.d_type == DT_DIR && recurse {
            let children = sourceFilesInDir(path + "/" + name)
            files.append(contentsOf: children.map({ name + "/" + $0 }))
        } else if name.hasSuffix(fileExtension) {
            files.append(name)
        }
    }
    closedir(dir)

    return files
}

func absolutePath(for filePath: String) -> String? {

    let url = URL(fileURLWithPath: filePath)
    do {
        guard try url.checkResourceIsReachable() else { return nil }
    } catch { return nil }

    let absoluteURL = url.absoluteString

    return absoluteURL.components(separatedBy: "file://").last
}

func absolutePath(for filepath: String, relativeTo file: String) -> String? {

    let fileUrl = URL(fileURLWithPath: file)
        .deletingLastPathComponent()
        .appendingPathComponent(filepath)

    do {
        guard try fileUrl.checkResourceIsReachable() else {
            return nil
        }
    } catch {
        return nil
    }

    let absoluteURL = fileUrl.absoluteString
    return absoluteURL.components(separatedBy: "file://").last
}

public func isDirectory(path: String) -> Bool {

    var buf = stat()
    if stat(path, &buf) != 0 {
        return false
    }
    return buf.st_mode & S_IFDIR != 0
}

func removeFile(at path: String) throws {

    let fm = FileManager.default

    try fm.removeItem(atPath: path)
}

extension Int {

    func round(upToNearest multiple: Int) -> Int {
        return (self + multiple - 1) & ~(multiple - 1)
    }

    func bytes() -> Int {
        return round(upToNearest: 8) / 8
    }

    func bitsNeeded() -> Int {
        return Int(floor(log2(Double(self - 1))) + 1)
    }
}

func unicodeScalarByteLength(_ leadingByte: UTF8.CodeUnit) -> Int {

    if 0b1_0000000 & leadingByte == 0 {
        return 1
    }
    if 0b11110000 & leadingByte == 0b11110000 {
        return 4
    }
    if 0b11100000 & leadingByte == 0b11100000 {
        return 3
    }
    if 0b11000000 & leadingByte == 0b11000000 {
        return 2
    }

    return 0
}

extension Unicode.Scalar {

    static let error = Unicode.Scalar(UInt32(0xFFFD))!
}
