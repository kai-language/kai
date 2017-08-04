// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension ForeignFuncLit {

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

