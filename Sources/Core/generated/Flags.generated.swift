// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension Binary {

    var isPtrMath: Bool {
        return flags.contains(.ptrMath) 
    }
}

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

    var isParameter: Bool {
        return flags.contains(.parameter) 
    }

    var isPolyParameter: Bool {
        return flags.contains(.polyParameter) 
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

    var isEmitObject: Bool {
        return flags.contains(.emitObject) 
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

    var isNoLink: Bool {
        return flags.contains(.noLink) 
    }

    var isNoCleanup: Bool {
        return flags.contains(.noCleanup) 
    }

    var isShared: Bool {
        return flags.contains(.shared) 
    }

    var isDynamicLib: Bool {
        return flags.contains(.dynamicLib) 
    }
}

extension Switch {

    var isUsing: Bool {
        return flags.contains(.using) 
    }

    var isType: Bool {
        return flags.contains(.type) 
    }

    var isAny: Bool {
        return flags.contains(.any) 
    }

    var isUnion: Bool {
        return flags.contains(.union) 
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

extension ty.Struct {

    var isPacked: Bool {
        return flags.contains(.packed) 
    }
}

extension ty.Union {

    var isInlineTag: Bool {
        return flags.contains(.inlineTag) 
    }
}

