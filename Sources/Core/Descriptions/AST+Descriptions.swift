
extension Node {

    // As a fall back we just return the text directly from the file
    var description: String {
        return currentPackage.sourceCode(from: start, to: end)
    }
}

extension Ident: CustomStringConvertible {
    var description: String {
        return name
    }
}

extension BasicLit: CustomStringConvertible {
    var description: String {
        return text
    }
}

extension Nil: CustomStringConvertible {
    var description: String {
        return "nil"
    }
}

extension Selector: CustomStringConvertible {
    var description: String {
        return String(describing: rec) + "." + sel.description
    }
}

extension Call: CustomStringConvertible {
    var description: String {

        let argumentList = "(" + args.map({ String(describing: $0) }).joined(separator: ", ") + ")"
        return String(describing: fun) + argumentList
    }
}

extension Unary: CustomStringConvertible {
    var description: String {
        return op.description + String(describing: element)
    }
}

extension Binary: CustomStringConvertible {
    var description: String {
        return String(describing: lhs) + " " + op.description + " " + String(describing: rhs)
    }
}
