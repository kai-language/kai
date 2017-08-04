
import LLVM

enum stdlib {

    static var module: Module = {
        return Module(name: "_kai_stdlib")
    }()

    static var builder: IRBuilder = {
        let builder = IRBuilder(module: module)

        // TODO: Declare stdlib builtins

        return builder
    }()
}

func canonicalize(_ type: Type) -> IRType {

    switch type {
    case is ty.Void:
        return VoidType()
    case is ty.Boolean:
        return IntType.int1
    case let type as ty.Integer:
        return IntType(width: type.width!)
    case let type as ty.FloatingPoint:
        switch type.width! {
        case 16: return FloatType.half
        case 32: return FloatType.float
        case 64: return FloatType.double
        case 80: return FloatType.x86FP80
        case 128: return FloatType.fp128
        default: fatalError()
        }
    case let type as ty.Pointer:
        return LLVM.PointerType(pointee: canonicalize(type.pointeeType))
    case let type as ty.Function:
        var paramTypes: [IRType] = []

        let requiredParams = type.isVariadic ? type.params[..<(type.params.endIndex - 1)] : ArraySlice(type.params)
        for param in requiredParams {
            let type = canonicalize(param)
            paramTypes.append(type)
        }

        let retType = canonicalize(type.returnType)

        return FunctionType(argTypes: paramTypes, returnType: retType, isVarArg: type.isCVariadic)
    case let type as ty.Struct:
        return type.ir.val!
    case let type as ty.Tuple:
        let types = type.types.map(canonicalize)
        switch types.count {
        case 1:
            return types[0]

        default:
            return LLVM.StructType(elementTypes: types, isPacked: true)
        }
    default:
        fatalError()
    }
}

