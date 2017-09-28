// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension Entity {

    var isBuiltin: Bool {
        return flags.contains(.builtin) 
    }

    var isChecked: Bool {
        return flags.contains(.checked) 
    }

    var isFile: Bool {
        return flags.contains(.file) 
    }

    var isLibrary: Bool {
        return flags.contains(.library) 
    }

    var isType: Bool {
        return flags.contains(.type) 
    }

    var isConstant: Bool {
        return flags.contains(.constant) 
    }

    var isImplicitType: Bool {
        return flags.contains(.implicitType) 
    }

    var isForeign: Bool {
        return flags.contains(.foreign) 
    }

    var isLabel: Bool {
        return flags.contains(.label) 
    }

    var isField: Bool {
        return flags.contains(.field) 
    }
}

extension FuncLit {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }

    var isDiscardable: Bool {
        return flags.contains(.discardable) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }
}

extension FuncType {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }

    var isDiscardable: Bool {
        return flags.contains(.discardable) 
    }

    var isSpecialization: Bool {
        return flags.contains(.specialization) 
    }
}

extension Options {

    var isNoCleanup: Bool {
        return flags.contains(.noCleanup) 
    }

    var isDumpIr: Bool {
        return flags.contains(.dumpIr) 
    }

    var isEmitIr: Bool {
        return flags.contains(.emitIr) 
    }

    var isEmitBitcode: Bool {
        return flags.contains(.emitBitcode) 
    }

    var isEmitAssembly: Bool {
        return flags.contains(.emitAssembly) 
    }

    var isEmitTimes: Bool {
        return flags.contains(.emitTimes) 
    }

    var isEmitDebugTimes: Bool {
        return flags.contains(.emitDebugTimes) 
    }

    var isEmitAst: Bool {
        return flags.contains(.emitAst) 
    }

    var isTestMode: Bool {
        return flags.contains(.testMode) 
    }
}

extension ty.Function {

    var isVariadic: Bool {
        return flags.contains(.variadic) 
    }

    var isCVariadic: Bool {
        return flags.contains(.cVariadic) 
    }

    var isPolymorphic: Bool {
        return flags.contains(.polymorphic) 
    }

    var isBuiltin: Bool {
        return flags.contains(.builtin) 
    }
}

