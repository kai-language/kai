
extension AST: CustomStringConvertible {
    func add(_ child: Node) {
        child.parent = self
        self.children.append(child)
    }

    func add(children: [Node]) {
        children.forEach(add)
    }

    var description: String {
        return pretty()
    }

    func mathy() -> String {
        var description = ""

        switch (kind, children.count) {
        case (.integer(let n), 0): description += n.description
        case (.identifier(let i), 0): description += i.description
        case (.operator(let symbol), 1): description += symbol.description + "(" + children.first!.mathy() + ")"
        case (.operator(let symbol), 2): description += "(" + children[0].mathy() + " " + symbol.description + " " + children[1].mathy() + ")"
        case (.assignment, 2): description += "(" + children[0].mathy() + " = " + children[1].mathy() + ")"
        case (.declaration, 2): description += "(" + children[0].mathy() + " := " + children[1].mathy() + ")"
        case (.subscript, 1): description += "(subscript\n" + children[0].mathy() + ")"

        case (.file(_), _): return children.reduce("", { str, node in str + node.mathy() + "\n" })
        default: fatalError()
        }
        return description
    }

    func pretty(depth: Int = 0) -> String {
        var description = ""

        let indentation = (0...depth).reduce("\n", { $0.0 + "  " })

        description += indentation + "(" + String(describing: kind)

        let childDescriptions = self.children
            .map { $0.pretty(depth: depth + 1) }
            .reduce("", { $0 + $1})

        description += childDescriptions

        description += ")"


        return description
    }
}
