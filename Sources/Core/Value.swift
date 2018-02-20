
protocol Value: CustomStringConvertible {}

extension UInt64: Value {}
extension Double: Value {}
extension String: Value {}
extension Nil: Value {}

func negate(_ value: Value) -> Value {
    switch value {
    case let value as UInt64:
        // FIXME: @important
        // FIXME: We can't use UInt64 any more because (obviously we can't negate it)
        //   What I want as a fix instead is a wide signed type in swift (Int256?)
        return value
    case let value as Double:
        return -value
    default:
        return value
    }
}

func not(_ value: Value) -> Value {
    // NOTE: if we do boolean values they will be represented by a number in swift
    switch value {
    case let value as UInt64:
        return value == 0 ? 0 : 1
    default:
        return value
    }
}

func bnot(_ value: Value) -> Value {
    guard let v = value as? UInt64 else {
        return value
    }
    return ~v
}

private func application(for token: Token) -> ((Value, Value) -> Value?)? {
    switch token {
    case .lss:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs < rhs ? 1 : 0
            case (let lhs as Double, let rhs as Double):
                return lhs < rhs ? 1 : 0
            case (let lhs as Double, let rhs as UInt64):
                return lhs < Double(rhs) ? 1 : 0
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) < rhs ? 1 : 0
            default:
                return nil
            }
        }
    case .leq:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs <= rhs ? 1 : 0
            case (let lhs as Double, let rhs as Double):
                return lhs <= rhs ? 1 : 0
            case (let lhs as Double, let rhs as UInt64):
                return lhs <= Double(rhs) ? 1 : 0
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) <= rhs ? 1 : 0
            default:
                return nil
            }
        }
    case .gtr:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs > rhs ? 1 : 0
            case (let lhs as Double, let rhs as Double):
                return lhs > rhs ? 1 : 0
            case (let lhs as Double, let rhs as UInt64):
                return lhs > Double(rhs) ? 1 : 0
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) > rhs ? 1 : 0
            default:
                return nil
            }
        }
    case .geq:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs >= rhs ? 1 : 0
            case (let lhs as Double, let rhs as Double):
                return lhs >= rhs ? 1 : 0
            case (let lhs as Double, let rhs as UInt64):
                return lhs >= Double(rhs) ? 1 : 0
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) >= rhs ? 1 : 0
            default:
                return nil
            }
        }
    case .eql:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs == rhs ? 1 : 0
            case (let lhs as Double, let rhs as Double):
                return lhs == rhs ? 1 : 0
            case (let lhs as Double, let rhs as UInt64):
                return lhs == Double(rhs) ? 1 : 0
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) == rhs ? 1 : 0
            default:
                return nil
            }
        }
    case .neq:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs != rhs ? 1 : 0
            case (let lhs as Double, let rhs as Double):
                return lhs != rhs ? 1 : 0
            case (let lhs as Double, let rhs as UInt64):
                return lhs != Double(rhs) ? 1 : 0
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) != rhs ? 1 : 0
            default:
                return nil
            }
        }
    case .xor:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs ^ rhs
            default:
                return nil
            }
        }
    case .and:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs & rhs
            default:
                return nil
            }
        }
    case .land:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return (lhs != 0) && (rhs != 0) ? 1 : 0
            default:
                return nil
            }
        }
    case .or:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs | rhs
            default:
                return nil
            }
        }
    case .lor:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return (lhs != 0) || (rhs != 0) ? 1 : 0
            default:
                return nil
            }
        }
    case .shl:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs << rhs
            default:
                return nil
            }
        }
    case .shr:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs >> rhs
            default:
                return nil
            }
        }
    case .add:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs + rhs
            case (let lhs as Double, let rhs as Double):
                return lhs + rhs
            case (let lhs as Double, let rhs as UInt64):
                return lhs + Double(rhs)
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) + rhs
            default:
                return nil
            }
        }
    case .sub:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs - rhs
            case (let lhs as Double, let rhs as Double):
                return lhs - rhs
            case (let lhs as Double, let rhs as UInt64):
                return lhs - Double(rhs)
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) - rhs
            default:
                return nil
            }
        }
    case .mul:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs * rhs
            case (let lhs as Double, let rhs as Double):
                return lhs * rhs
            case (let lhs as Double, let rhs as UInt64):
                return lhs * Double(rhs)
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) * rhs
            default:
                return nil
            }
        }
    case .quo:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs / rhs
            case (let lhs as Double, let rhs as Double):
                return lhs / rhs
            case (let lhs as Double, let rhs as UInt64):
                return lhs / Double(rhs)
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) / rhs
            default:
                return nil
            }
        }
    case .rem:
        return { lhs, rhs in
            switch (lhs, rhs) {
            case (let lhs as UInt64, let rhs as UInt64):
                return lhs + rhs
            case (let lhs as Double, let rhs as Double):
                return lhs + rhs
            case (let lhs as Double, let rhs as UInt64):
                return lhs + Double(rhs)
            case (let lhs as UInt64, let rhs as Double):
                return Double(lhs) + rhs
            default:
                return nil
            }
        }
    default:
        return { _, _ in nil }
    }
}

func apply(_ lhs: Value?, _ rhs: Value?, op: Token) -> Value? {
    guard let lhs = lhs, let rhs = rhs else {
        return nil
    }
    return application(for: op)?(lhs, rhs)
}
