
import Darwin

class Ref<T> {
    var val: T
    init(_ val: T) {
        self.val = val
    }

// sourcery:inline:auto:Ref.Init
init(val: T) {
    self.val = val
}
// sourcery:end
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
