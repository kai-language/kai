import LLVM

extension Entity {

    func canonicalized() throws -> IRType {
        guard let type = self.type else {
            fatalError("\(#function) called for unresolved type for Entity: \(self)")
        }

        return try type.canonicalized()
    }
}
