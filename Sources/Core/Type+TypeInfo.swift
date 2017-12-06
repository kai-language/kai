
//Compound = 0b000
//Boolean  = 0b001
//Integer  = 0b010
//Float    = 0b011
//Any      = 0b100

import LLVM

func typeInfoTag(for type: Type) -> UInt8 {
    switch type {
    case is ty.Boolean:
        return 0b001
    case is ty.Integer:
        return 0b010
    case is ty.FloatingPoint:
        return 0b011
    case is ty.Anyy:
        return 0b100

    default:
        return 0b000
    }
}

func generateTypeInfoLLVM(_ gen: inout IRGenerator) -> (type: LLVM.StructType, boolean: LLVM.StructType, integer: LLVM.StructType, floatingPoint: LLVM.StructType) {

    let type = gen.canonicalize(ty.typeInfo)
    let boolean = gen.canonicalize(ty.booleanType)
    let integer = gen.canonicalize(ty.integerType)
    let floatingPoint = gen.canonicalize(ty.floatType)

    return (type, boolean, integer, floatingPoint) as! (LLVM.StructType, LLVM.StructType, LLVM.StructType, LLVM.StructType)
}
