
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

extension AST.Node {
    var conditionalBodies: (conditional: Node, trueBody: Node, elseBody: Node?)? {
        guard case .conditional = kind, children.count >= 2 else {
            return nil
        }
        
        let conditional = children[0]
        let trueBody = children[1]
        var elseBody: Node? = nil
        
        if children.count > 2 {
            elseBody = children[2]
        }
        
        return (conditional, trueBody, elseBody)
        
    }
}
