import LLVM

extension Entity {

    func canonicalized() throws -> IRType {
        guard let type = self.type else {
            panic(self)
        }

        return try type.canonicalized()
    }
}
