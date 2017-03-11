
import Foundation.NSFileManager

extension FileManager {

    func absolutePath(for filePath: String) -> String? {

        let url = URL(fileURLWithPath: filePath)
        do {
            guard try url.checkResourceIsReachable() else { return nil }
        } catch { return nil }

        let absoluteURL = url.absoluteString

        return absoluteURL.components(separatedBy: "file://").last
    }

    func absolutePath(for filepath: String, relativeTo file: ASTFile) -> String? {

        let fileUrl = URL(fileURLWithPath: file.fullpath)
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
}

extension String {

    enum Escape {
        static let red = "\u{001B}[34m"
        static let blue = "\u{001B}[31m"
        static let reset: String = "\u{001B}[0m"
    }

    var red: String {
        return Escape.reset + Escape.red + self + Escape.reset
    }

    var blue: String {
        return Escape.reset + Escape.blue + self + Escape.reset
    }
}

typealias Byte = UInt8

/*
    Miscelaneous methods extensions and other tidbits of useful functionality
    that is general enough to not belong in other files.
*/

extension BidirectionalCollection where Index == Int {

    /// The Actual last indexable position of the array
    var lastIndex: Index {
        return endIndex - 1
    }
}

extension Set {

    init<S: Sequence>(_ sequences: S...)
        where S.Iterator.Element: Hashable, S.Iterator.Element == Element
    {

        self.init()

        for element in sequences.joined() {
            insert(element)
        }
    }
}


extension String {

    // God, why does the stdlib not have such simple things.
    func split(separator: Character) -> [String] {
        return self.characters.split(separator: separator).map(String.init)
    }

    init(_ unicodeScalars: [UnicodeScalar]) {
        self.init(unicodeScalars.map(Character.init))
    }

    /// This was removed from the stdlib I guess ...
    mutating func append(_ scalar: UnicodeScalar) {
        self.append(Character(scalar))
    }
}

// Combats Boilerplate
extension ExpressibleByStringLiteral where StringLiteralType == StaticString {

    public init(unicodeScalarLiteral value: StaticString) {
        self.init(stringLiteral: value)
    }

    public init(extendedGraphemeClusterLiteral value: StaticString) {
        self.init(stringLiteral: value)
    }
}

// NOTE(vdka): This should only be used in development, there are better ways to do things.
func isMemoryEquivalent<A, B>(_ lhs: A, _ rhs: B) -> Bool {
    var (lhs, rhs) = (lhs, rhs)

    guard MemoryLayout<A>.size == MemoryLayout<B>.size else { return false }

    let lhsPointer = withUnsafePointer(to: &lhs) { $0 }
    let rhsPointer = withUnsafePointer(to: &rhs) { $0 }

    let lhsFirstByte = unsafeBitCast(lhsPointer, to: UnsafePointer<Byte>.self)
    let rhsFirstByte = unsafeBitCast(rhsPointer, to: UnsafePointer<Byte>.self)

    let lhsBytes = UnsafeBufferPointer(start: lhsFirstByte, count: MemoryLayout<A>.size)
    let rhsBytes = UnsafeBufferPointer(start: rhsFirstByte, count: MemoryLayout<B>.size)

    for (leftByte, rightByte) in zip(lhsBytes, rhsBytes) {
        guard leftByte == rightByte else { return false }
    }

    return true
}

extension Collection where Index: Comparable {
    subscript (safe index: Index) -> Generator.Element? {
        guard startIndex <= index && index < endIndex else {
            return nil
        }
        return self[index]
    }
}

func longZip<S1: Sequence, S2: Sequence>(_ seq1: S1, _ seq2: S2) -> AnySequence<(S1.Iterator.Element?, S2.Iterator.Element?)> {

    var (iter1, iter2) = (seq1.makeIterator(), seq2.makeIterator())

    return AnySequence {
        return AnyIterator { () -> (S1.Iterator.Element?, S2.Iterator.Element?)? in
            let (l, r) = (iter1.next(), iter2.next())
            switch (l, r) {
            case (nil, nil):
                return nil

            default:
                return (l, r)
            }
        }
    }
}

import Darwin

func unimplemented(_ featureName: String, file: StaticString = #file, line: UInt = #line) -> Never {
    print("\(file):\(line): Unimplemented feature \(featureName).")
    exit(1)
}

func unimplemented(_ featureName: String, if predicate: Bool, file: StaticString = #file, line: UInt = #line) {
    if predicate {
        unimplemented(featureName, file: file, line: line)
    }
}

func debug<T>(_ value: T, file: StaticString = #file, line: UInt = #line) {
    print("\(line): \(value)")
    fflush(stdout)
}

func debug(file: StaticString = #file, line: UInt = #line) {
    print("\(line): HERE")
    fflush(stdout)
}

func unimplemented(file: StaticString = #file, line: UInt = #line) -> Never {
    print("\(file):\(line): Unimplemented feature.")
    exit(1)
}
