
/// This scanner class allows arbitrary lookahead
struct BufferedScanner<Element> {

    var iterator: AnyIterator<Element>

    /// Buffer is always the tokens that follow last `pop` the number depends on how far we have peeked
    var buffer: [Element] = []

    init(_ iterator: AnyIterator<Element>) {

        self.buffer = []
        self.iterator = iterator
    }

    init<I: IteratorProtocol>(_ iterator: I) where I.Element == Element {

        self.buffer = []
        self.iterator = AnyIterator(iterator)
    }

    init<S: Sequence>(_ seq: S) where S.Iterator.Element == Element {

        self.buffer = []
        let iter = seq.makeIterator()
        self.iterator = AnyIterator(iter)
    }
}

extension BufferedScanner {

    mutating func peek(aheadBy n: Int = 0) -> Element? {
        guard buffer.count <= n else {
            return buffer[n]
        }

        guard let element = iterator.next() else { return nil }

        buffer.append(element)
        return buffer.last
    }

    /// - Precondition: Call to peek first to ensure the underlying sequence has not been exhausted
    @discardableResult
    mutating func pop() -> Element {

        switch buffer.isEmpty {
        case true:  return iterator.next()!
        case false: return buffer.removeFirst()
        }
    }
}

/*
extension File {
    func generateVerboseLineOf(error position: SourceLocation) -> String {
        let line = position.line
        let column = position.column

        var currentLine: UInt = 1
        var peeked = 0

        //reset filepointer back to the beginning
        self.pointer = basePointer
        var scanner = FileScanner(file: self)

        var isConsuming = false
        var consumed: ByteString = ""
        while let byte = scanner.peek(aheadBy: peeked) {
            peeked += 1

            if byte == "\n" {
                currentLine += 1
                if isConsuming {
                    break
                }
            }

            if isConsuming {
                consumed.append(byte)
            }

            if currentLine == line && !isConsuming {
                isConsuming = true
            }
        }

        //TODO(Brett): if an error message is longer than 80 characters take an
        //80 character chunk (preferably) centred around the `column`
        let TAB = "      " //4 spaces
        /*let TERM_WIDTH = 80

         let sourceLineLength = consumed.count
         let sourceLineString: String

         if sourceLineLength > TERM_WIDTH {
         // _ _ X _ _ _ _ _ _
         // _ _ _ _ X _ _ _ _
         // _ _ _ _ _ _ X _ _
         } else {
         sourceLineString = String(consumed)
         }*/

        //TODO(Brett): Cleanup creation of String, make some helper functions
        let count = column - 1
        let pointerString = String(repeating: " ", count: Int(count))
        return "\(TAB)\(String(consumed))" + "\n\(TAB)\(pointerString)^"
    }
}
*/
