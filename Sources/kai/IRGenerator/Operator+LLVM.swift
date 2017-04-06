
import LLVM


extension IRGenerator {

    // TODO(vdka): Check the types to determine llvm calls
    func emitOperator(for node: AstNode) -> IRValue {

        switch node {
        case .exprUnary(let op, let expr, _):
            let type = checker.info.types[expr]!

            // TODO(vdka): There is much more to build.
            switch op {
            case .plus: // This is oddly a do nothing kind of operator. Lazy guy.
                return emitStmt(for: expr)

            case .minus:
                let val = emitStmt(for: expr)
                return builder.buildNeg(val)

            case .bang:
                let val = emitStmt(for: expr)
                if type === Type.bool {
                    return builder.buildNot(val)
                } else {
                    let truncdVal = builder.buildTrunc(val, type: IntType.int1)
                    return builder.buildNot(truncdVal)
                }

            case .tilde:
                let val = emitStmt(for: expr)
                return builder.buildNot(val)

            case .ampersand:
                switch expr {
                case .ident(let name, _):
                    let entity = context.scope.lookup(name)!
                    return llvmPointers[entity]!
                    
                default:
                    return emitStmt(for: expr)
                }

            case .asterix:

                switch type.kind {
                case .pointer(let underlyingType),
                     .nullablePointer(let underlyingType):

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
                if lhsType.isUnconstrained && !lhs.isBasicLit {
                    if lhsType.isUnsigned {
                        lvalue = builder.buildZExt(lvalue, type: rvalue.type)
                    } else {
                        lvalue = builder.buildSExt(lvalue, type: rvalue.type)
                    }
                }
                if rhsType.isUnconstrained && !rhs.isBasicLit {
                    if rhsType.isUnsigned {
                        rvalue = builder.buildZExt(rvalue, type: lvalue.type)
                    } else {
                        rvalue = builder.buildSExt(rvalue, type: lvalue.type)
                    }
                }
            }

            switch op {
            case .plus:
                return builder.buildAdd(lvalue, rvalue)

            case .minus:
                return builder.buildSub(lvalue, rvalue)

            case .asterix:
                return builder.buildMul(lvalue, rvalue)

            case .slash:
                if lhsType.isUnsigned {

                    return builder.buildDiv(lvalue, rvalue, signed: false)
                } else {

                    return builder.buildDiv(lvalue, rvalue, signed: true)
                }

            case .percent:
                if lhsType.isUnsigned {

                    return builder.buildRem(lvalue, rvalue, signed: false)
                } else {

                    return builder.buildRem(lvalue, rvalue, signed: true)
                }

            // TODO(vdka): Are these arithmatic or logical? Which should they be?
            case .doubleLeftChevron:
                return builder.buildShl(lvalue, rvalue)

            case .doubleRightChevron:
                return builder.buildShr(lvalue, rvalue)

            case .leftChevron:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedLessThan)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedLessThan)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedLessThan)
                }
                panic()

            case .leftChevronEquals:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedLessThanOrEqual)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedLessThanOrEqual)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedLessThanOrEqual)
                }
                panic()

            case .rightChevron:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThan)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedGreaterThan)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedGreaterThan)
                }
                panic()

            case .rightChevronEquals:
                if lhsType.isUnsigned {
                    return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThanOrEqual)
                } else if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .signedGreaterThanOrEqual)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedGreaterThanOrEqual)
                }
                panic()

            case .equalsEquals:
                if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .equal)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedEqual)
                }
                panic()

            case .bangEquals:
                if lhsType.isInteger {
                    return builder.buildICmp(lvalue, rvalue, .notEqual)
                } else if lhsType.isFloat {
                    return builder.buildFCmp(lvalue, rvalue, .orderedNotEqual)
                }
                return builder.buildICmp(lvalue, rvalue, .notEqual)

            case .ampersand:
                return builder.buildAnd(lvalue, rvalue)

            case .pipe:
                return builder.buildOr(lvalue, rvalue)

            case .carot:
                return builder.buildXor(lvalue, rvalue)

            case .doubleAmpersand:
                let r = builder.buildAnd(lvalue, rvalue)
                return builder.buildTrunc(r, type: IntType.int1)

            case .doublePipe:
                let r = builder.buildOr(lvalue, rvalue)
                return builder.buildTrunc(r, type: IntType.int1)

            default:
                unimplemented("Binary Operator '\(op)'")
            }

        default:
            fatalError()
        }
    }
    
    func emitSubscript(for node: AstNode, isLValue: Bool) -> IRValue {
        guard case .exprSubscript(let receiver, let value, _) = node else {
            preconditionFailure()
        }
        
        let lvalue: IRValue
        
        switch receiver {
        case .ident(let identifier, _):
            let entity = context.scope.lookup(identifier)!
            lvalue = llvmPointers[entity]!
            
        default:
            unimplemented()
        }

        let index = emitStmt(for: value)
        
        let ptr = builder.buildGEP(lvalue, indices: [
            IntType.int64.constant(0),
            index
        ])
        
        // set
        if isLValue {
            return ptr
        }
        
        //get
        return builder.buildLoad(ptr)
    }
}
