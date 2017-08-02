import LLVM

final class Checker {
    var file: SourceFile

    init(file: SourceFile) {
        self.file = file
    }

// sourcery:inline:auto:Checker.Init
init(file: SourceFile) {
    self.file = file
}
// sourcery:end
}
