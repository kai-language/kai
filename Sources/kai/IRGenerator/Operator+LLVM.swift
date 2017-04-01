
import LLVM


extension IRGenerator {

    // TODO(vdka): Check the types to determine llvm calls
    func emitOperator(for node: AstNode) -> IRValue {

        switch node {
        case .exprUnary(let op, let expr, _):
            let type = checker.info.types[expr]!

            // TODO(vdka): There is much more to build.
            switch op {
            case "+": // This is oddly a do nothing kind of operator. Lazy guy.
                return emitStmt(for: expr)

            case "-":
                let val = emitStmt(for: expr)
                return builder.buildNeg(val)

            case "!":
                let val = emitStmt(for: expr)
                if type === Type.bool {
                    return builder.buildNot(val)
                } else {
                    let truncdVal = builder.buildTrunc(val, type: IntType.int1)
                    return builder.buildNot(truncdVal)
                }

            case "~":
                let val = emitStmt(for: expr)
                return builder.buildNot(val)

            case "&":
                switch expr {
                case .ident(let name, _):
                    let entity = context.scope.lookup(name)!
                    return llvmPointers[entity]!
                    
                default:
                    return emitStmt(for: expr)
                }

            case "*":
                guard case .pointer(let underlyingType) = type.kind else {
                    preconditionFailure()
                }
                
                switch underlyingType.kind {
                case .alias(_, _):
                    unimplemented()
                    
                case .named:
                    let val = emitStmt(for: expr)
                    return builder.buildLoad(val)
                
                default:
                    preconditionFailure()
                }
                
            default:
                unimplemented("Unary Operator '\(op)'")
            }

        case .exprBinary(let op, let lhs, let rhs, _):

            var lvalue = emitStmt(for: lhs)
            var rvalue = emitStmt(for: rhs)

            let lhsType = checker.info.types[lhs]!
            let rhsType = checker.info.types[rhs]!

            // TODO(vdka): Trunc or Ext if needed / possible

            if lhsType !== rhsType {
                if lhsType.width == rhsType.width {
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
                if lhsType.flags.contains(.unsigned) {

                    return builder.buildDiv(lvalue, rvalue, signed: false)
                } else {

                    return builder.buildDiv(lvalue, rvalue, signed: true)
                }

            case "%":
                if lhsType.flags.contains(.unsigned) {

                    return builder.buildRem(lvalue, rvalue, signed: false)
                } else {

                    return builder.buildRem(lvalue, rvalue, signed: true)
                }

            // TODO(vdka): Are these arithmatic or logical? Which should they be?
            case "<<":
                return builder.buildShl(lvalue, rvalue)

            case ">>":
                return builder.buildShr(lvalue, rvalue)

            case "<":
                if lhsType.flags.contains(.unsigned) {
                    return builder.buildICmp(lvalue, rvalue, .unsignedLessThan)
                } else if lhsType.flags.contains(.integer) {
                    return builder.buildICmp(lvalue, rvalue, .signedLessThan)
                } else if lhsType.flags.contains(.float) {
                    return builder.buildFCmp(lvalue, rvalue, .orderedLessThan)
                }
                panic()

            case "<=":
                if lhsType.flags.contains(.unsigned) {
                    return builder.buildICmp(lvalue, rvalue, .unsignedLessThanOrEqual)
                } else if lhsType.flags.contains(.integer) {
                    return builder.buildICmp(lvalue, rvalue, .signedLessThanOrEqual)
                } else if lhsType.flags.contains(.float) {
                    return builder.buildFCmp(lvalue, rvalue, .orderedLessThanOrEqual)
                }
                panic()

            case ">":
                if lhsType.flags.contains(.unsigned) {
                    return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThan)
                } else if lhsType.flags.contains(.integer) {
                    return builder.buildICmp(lvalue, rvalue, .signedGreaterThan)
                } else if lhsType.flags.contains(.float) {
                    return builder.buildFCmp(lvalue, rvalue, .orderedGreaterThan)
                }
                panic()

            case ">=":
                if lhsType.flags.contains(.unsigned) {
                    return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThanOrEqual)
                } else if lhsType.flags.contains(.integer) {
                    return builder.buildICmp(lvalue, rvalue, .signedGreaterThanOrEqual)
                } else if lhsType.flags.contains(.float) {
                    return builder.buildFCmp(lvalue, rvalue, .orderedGreaterThanOrEqual)
                }
                panic()

            case "==":
                if lhsType.flags.contains(.integer) {
                    return builder.buildICmp(lvalue, rvalue, .equal)
                } else if lhsType.flags.contains(.float) {
                    return builder.buildFCmp(lvalue, rvalue, .orderedEqual)
                }
                panic()

            case "!=":
                if lhsType.flags.contains(.integer) {
                    return builder.buildICmp(lvalue, rvalue, .notEqual)
                } else if lhsType.flags.contains(.float) {
                    return builder.buildFCmp(lvalue, rvalue, .orderedNotEqual)
                }
                return builder.buildICmp(lvalue, rvalue, .notEqual)

            case "&":
                return builder.buildAnd(lvalue, rvalue)

            case "|":
                return builder.buildOr(lvalue, rvalue)

            case "^":
                return builder.buildXor(lvalue, rvalue)

            case "&&":
                let r = builder.buildAnd(lvalue, rvalue)
                return builder.buildTrunc(r, type: IntType.int1)

            case "||":
                let r = builder.buildOr(lvalue, rvalue)
                return builder.buildTrunc(r, type: IntType.int1)

            case "+=":
                let r = builder.buildAdd(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "-=":
                let r = builder.buildSub(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "*=":
                let r = builder.buildMul(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "/=":
                let r: IRValue
                if lhsType.flags.contains(.unsigned) {

                    r = builder.buildDiv(lvalue, rvalue, signed: false)
                } else {

                    r = builder.buildDiv(lvalue, rvalue, signed: true)
                }
                return builder.buildStore(r, to: lvalue)

            case "%=":
                let r: IRValue
                if lhsType.flags.contains(.unsigned) {

                    r = builder.buildRem(lvalue, rvalue, signed: false)
                } else {

                    r = builder.buildRem(lvalue, rvalue, signed: true)
                }
                return builder.buildStore(r, to: lvalue)

            case ">>=": // FIXME(vdka): Arithmatic shift?
                let r = builder.buildShr(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "<<=":
                let r = builder.buildShl(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "&=":
                let r = builder.buildAnd(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "|=":
                let r = builder.buildOr(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            case "^=":
                let r = builder.buildXor(lvalue, rvalue)
                return builder.buildStore(r, to: lvalue)

            default:
                unimplemented("Binary Operator '\(op)'")
            }

        default:
            fatalError()
        }
    }
}
