#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Foundation
import LLVM

var targetMachine: TargetMachine!

public func setupTargetMachine(targetTriple: String?) {
    do {
        targetMachine = try TargetMachine(triple: targetTriple)
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

    for package in compiler.packages.values.filter({ !$0.isInitialPackage }) {
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
}

extension Collection {

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

extension String {
    func commonPathPrefix(with rhs: String) -> String.Index {
        let lhs = self
        let count = lhs.count > rhs.count ? lhs.count : rhs.count

        var lastPath = 0
        for i in 0..<Int(count) {
            let a = lhs[lhs.index(lhs.startIndex, offsetBy: i)]
            let b = rhs[rhs.index(rhs.startIndex, offsetBy: i)]

            guard a == b else {
                if lastPath > 0 { lastPath += 1 } // don't include the final `/`
                return lhs.index(lhs.startIndex, offsetBy: lastPath)
            }

            if a == "/" {
                lastPath = i
            }
        }

        return lhs.index(lhs.startIndex, offsetBy: count)
    }
}

func removeFile(at path: String) throws {

    let fm = FileManager.default

    try fm.removeItem(atPath: path)
}

func isPowerOfTwo<I: BinaryInteger>(_ value: I) -> Bool {
    return (value > 0) && (value & (value - 1) == 0)
}

func highestBitForValue<I: BinaryInteger, O: BinaryInteger>(_ value: I) -> O {
    return numericCast(1 << (numericCast(value) - 1))
}

func positionOfHighestBit<I: BinaryInteger, O: BinaryInteger>(_ value: I) -> O {
    return numericCast(ffsl(numericCast(value)))
}

func maxValueForInteger<I: BinaryInteger, O: BinaryInteger>(width: I, signed: Bool) -> O {
    let allOnes = ~I(0)
    if signed {
        return numericCast((1 << (width - 1)) - 1)
    } else {
        return numericCast(~(allOnes << width))
    }
}

func minValueForSignedInterger<I: BinaryInteger, O: BinaryInteger>(width w: I) -> O {
    return numericCast(-1 * (1 << (w - 1)))
}

extension Int {

    func round(upToNearest multiple: Int) -> Int {
        return (self + multiple - 1) & ~(multiple - 1)
    }

    func nextLoadablePowerOfTwoAlignment() -> Int {
        var n = self
        n -= 1
        n |= n >> 1
        n |= n >> 2
        n |= n >> 4
        n |= n >> 8
        n |= n >> 16
        n += 1
        if n < 8 {
            return 8
        }
        return n
    }

    func bytes() -> Int {
        return round(upToNearest: 8) / 8
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

func assert(_ a: Bool, implies b: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    assert(!a || b(), message, file: file, line: line)
}

public enum AnsiColor: UInt8 {
    case black = 30
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
    case lightBlack = 90
    case lightRed
    case lightGreen
    case lightYellow
    case lightBlue
    case lightMagenta
    case lightCyan
    case lightWhite

    public var value: UInt8 {
        return rawValue
    }
}

extension String {

    public func applyingColor(_ code: AnsiColor) -> String {
        let ESC = "\u{001B}[0;"
        return "\(ESC)\(code.rawValue)m\(self)\u{001B}[0m"
    }

    var black: String { return applyingColor(.black) }
    var red: String { return applyingColor(.red) }
    var green: String { return applyingColor(.green) }
    var yellow: String { return applyingColor(.yellow) }
    var blue: String { return applyingColor(.blue) }
    var magenta: String { return applyingColor(.magenta) }
    var cyan: String { return applyingColor(.cyan) }
    var white: String { return applyingColor(.white) }
    var lightBlack: String { return applyingColor(.lightBlack) }
    var lightRed: String { return applyingColor(.lightRed) }
    var lightGreen: String { return applyingColor(.lightGreen) }
    var lightYellow: String { return applyingColor(.lightYellow) }
    var lightBlue: String { return applyingColor(.lightBlue) }
    var lightMagenta: String { return applyingColor(.lightMagenta) }
    var lightCyan: String { return applyingColor(.lightCyan) }
    var lightWhite: String { return applyingColor(.lightWhite) }
}
