
protocol Value {}

extension UInt64: Value {}
extension Double: Value {}
extension String: Value {}

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
