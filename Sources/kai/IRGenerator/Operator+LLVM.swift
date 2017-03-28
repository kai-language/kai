
import LLVM

extension IRGenerator {

    // TODO(vdka): Check the types to determine llvm calls
    func emitOperator(for node: AstNode) -> IRValue {

        switch node {
        case .exprUnary(let op, let expr, _):

            let val = emitStmt(for: expr)
            let type = checker.info.types[expr]!

            // TODO(vdka): There is much more to build.
            switch op {
            case "+": // This is oddly a do nothing kind of operator. Lazy guy.
                return val

            case "-":
                return builder.buildNeg(val)

            case "!":
                if type === Type.bool {
                    return builder.buildNot(val)
                } else {
                    let truncdVal = builder.buildTrunc(val, type: IntType.int1)
                    return builder.buildNot(truncdVal)
                }

            case "~":
                return builder.buildNot(val)

            default:
                unimplemented("Unary Operator '\(op)'")
            }

        case .exprBinary(let op, let lhs, let rhs, _):

            var lvalue = emitStmt(for: lhs)
            var rvalue = emitStmt(for: rhs)

            let lhsType = checker.info.types[lhs]!
            let rhsType = checker.info.types[rhs]!

            if lhsType !== rhsType {
                if lhsType.size == rhsType.size {
                    //
                    // `x: uint = 1; y: int = 1; z := x + y`
                    // We don't know what the return type should be so it's an error caught in the checker
                    //
                    panic()
                }
                if lhsType.flags.contains(.unconstrained) && !lhs.isBasicLit {
                    if lhsType.flags.contains(.unsigned) {
                        lvalue = builder.buildZExt(lvalue, type: rvalue.type)
                    } else {
                        lvalue = builder.buildSExt(lvalue, type: rvalue.type)
                    }
                }
                if rhsType.flags.contains(.unconstrained) && !rhs.isBasicLit {
                    if rhsType.flags.contains(.unsigned) {
                        rvalue = builder.buildZExt(rvalue, type: lvalue.type)
                    } else {
                        rvalue = builder.buildSExt(rvalue, type: lvalue.type)
                    }
                }
            }

            switch op {
            case "+":
                return builder.buildAdd(lvalue, rvalue)

            case "-":
                return builder.buildSub(lvalue, rvalue)

            case "*":
                return builder.buildMul(lvalue, rvalue)

            case "/":
                return builder.buildDiv(lvalue, rvalue)

            case "%":
                return builder.buildRem(lvalue, rvalue)

            // TODO(vdka): Are these arithmatic or logical? Which should they be?
            case "<<":
                return builder.buildShl(lvalue, rvalue)

            case ">>":
                return builder.buildShr(lvalue, rvalue)

            case "<":
                return builder.buildICmp(lvalue, rvalue, .unsignedLessThan)

            case "<=":
                return builder.buildICmp(lvalue, rvalue, .unsignedLessThanOrEqual)

            case ">":
                return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThan)

            case ">=":
                return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThanOrEqual)

            case "==":
                return builder.buildICmp(lvalue, rvalue, .equal)

            case "!=":
                return builder.buildICmp(lvalue, rvalue, .notEqual)

            // TODO: returns: A value representing the logical AND. This isn't what the bitwise operators are.
            case "&":
                unimplemented()
                //            return builder.buildAnd(lvalue, rvalue)

            case "|":
                unimplemented()
                //            return builder.buildOr(lvalue, rvalue)

            case "^":
                unimplemented()
                //            return builder.buildXor(lvalue, rvalue)

            case "&&":
                return builder.buildAnd(lvalue, rvalue)

            case "||":
                return builder.buildOr(lvalue, rvalue)

            case "+=",
                 "-=",
                 "*=",
                 "/=",
                 "%=":
                unimplemented()

            case ">>=",
                 "<<=":
                unimplemented()

            case "&=",
                 "|=",
                 "^=":
                unimplemented()

            default:
                unimplemented("Binary Operator '\(op)'")
            }

        default:
            fatalError()
        }
    }
}
