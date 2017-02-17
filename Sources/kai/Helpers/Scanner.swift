struct Scanner<Element> {
    var pointer: UnsafePointer<Element>
    var elements: UnsafeBufferPointer<Element>
    let endAddress: UnsafePointer<Element>
    // assuming you don't mutate no copy _should_ occur
    let elementsCopy: [Element]
}

extension Scanner {
    init(_ data: [Element]) {
        self.elementsCopy = data
        self.elements = elementsCopy.withUnsafeBufferPointer { $0 }
        self.endAddress = elements.endAddress
        self.pointer = elements.baseAddress!
    }
}

extension Scanner {
    func peek(aheadBy n: Int = 0) -> Element? {
        guard pointer.advanced(by: n) < endAddress else { return nil }
        return pointer.advanced(by: n).pointee
    }

    /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
    @discardableResult
    mutating func pop() -> Element {
        assert(pointer != endAddress)
        defer { pointer = pointer.advanced(by: 1) }
        return pointer.pointee
    }

    /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
    @discardableResult
    mutating func attemptPop() throws -> Element {
        guard pointer < endAddress else { throw ScannerError.Reason.endOfStream }
        defer { pointer = pointer.advanced(by: 1) }
        return pointer.pointee
    }

    mutating func pop(_ n: Int) {
        
    }
}

extension Scanner {
    var isEmpty: Bool {
        return pointer == endAddress
    }
}

struct ScannerError: Swift.Error {
    let position: UInt
    let reason: Reason

    enum Reason: Swift.Error {
        case endOfStream
    }
}

extension UnsafeBufferPointer {
    fileprivate var endAddress: UnsafePointer<Element> {

        return baseAddress!.advanced(by: endIndex)
    }
}
