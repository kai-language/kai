
import LLVM

extension IRGenerator {

    func emitOperator(for node: AST.Node) throws -> IRValue {
        // FIXME: For now I am a slacker who has only implemented binary operators
        precondition(node.children.count == 2)

        let lvalueNode = node.children[0]
        let rvalueNode = node.children[1]

        // FIXME: Worse I have limitted it to same type with a precondition

        let lvalue = try emitValue(for: lvalueNode)
        let rvalue = try emitValue(for: rvalueNode)

        // @Types
        // FIXME: Once we have types for these nodes we can generate the appropriate calls based off of that.
        switch node.kind {
        case .operator("+"):
            return builder.buildAdd(lvalue, rvalue)

        case .operator("-"):
            return builder.buildSub(lvalue, rvalue)

        case .operator("*"):
            return builder.buildMul(lvalue, rvalue)

        case .operator("/"):
            return builder.buildDiv(lvalue, rvalue)

        case .operator("%"):
            return builder.buildRem(lvalue, rvalue)

        // TODO(vdka): Are these arithmatic or logical? Which should they be?
        case .operator("<<"):
            return builder.buildShl(lvalue, rvalue)

        case .operator(">>"):
            return builder.buildShr(lvalue, rvalue)

        case .operator("<"):
            return builder.buildICmp(lvalue, rvalue, .unsignedLessThan)

        case .operator("<="):
            return builder.buildICmp(lvalue, rvalue, .unsignedLessThanOrEqual)

        case .operator(">"):
            return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThan)

        case .operator(">="):
            return builder.buildICmp(lvalue, rvalue, .unsignedGreaterThanOrEqual)

        case .operator("=="):
            return builder.buildICmp(lvalue, rvalue, .equal)

        case .operator("!="):
            return builder.buildICmp(lvalue, rvalue, .notEqual)

        // TODO: returns: A value representing the logical AND. This isn't what the bitwise operators are.
        case .operator("&"):
            unimplemented()
//            return builder.buildAnd(lvalue, rvalue)

        case .operator("|"):
            unimplemented()
//            return builder.buildOr(lvalue, rvalue)

        case .operator("^"):
            unimplemented()
//            return builder.buildXor(lvalue, rvalue)

        case .operator("&&"):
            return builder.buildAnd(lvalue, rvalue)

        case .operator("||"):
            return builder.buildOr(lvalue, rvalue)
            
        case .operator("+="),
             .operator("-="),
             .operator("*="),
             .operator("/="),
             .operator("%="):
            unimplemented()
            
        case .operator(">>="),
             .operator("<<="):
            unimplemented()
            
        case .operator("&="),
             .operator("|="),
             .operator("^="):
            unimplemented()


        case .operator(let op):
            throw Error.invalidOperator(op.string)

        default:
            preconditionFailure("Invalid node type \(node) passed to \(#function)")
        }
    }
}
