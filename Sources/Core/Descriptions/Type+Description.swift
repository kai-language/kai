
extension ty.Void: CustomStringConvertible {
    var description: String {
        return "< void >"
    }
}

extension ty.Boolean {
    var description: String {
        return "< bool >"
    }
}

extension ty.Integer {
    var description: String {
        return "< \(isSigned ? "i" : "u")\(width!) >"
    }
}

extension ty.FloatingPoint {
    var description: String {
        return "< f\(width!) >"
    }
}

extension ty.KaiString {
    var description: String {
        return "< string >"
    }
}

extension ty.Pointer {
    var description: String {
        return "*" + pointeeType.description
    }
}

extension ty.Anyy {
    var description: String {
        return "< any >"
    }
}

extension ty.Struct {
    var description: String {
        return "struct{" + fields.map({ $0.ident.name + ": " + $0.type.description }).joined(separator: ", ") + "}"
    }
}

extension ty.Array {
    var description: String {
        return "[\(length)]" + elementType.description
    }
}

extension ty.DynamicArray {
    var description: String {
        return "[..]" + elementType.description
    }
}

extension ty.Function {
    var description: String {
        return "(" + params.map({ $0.description }).joined(separator: ", ") + ") -> " + returnType.description
    }
}

extension ty.UntypedNil {
    var description: String {
        return "nil"
    }
}

extension ty.UntypedInteger {
    var description: String {
        return "integer"
    }
}

extension ty.UntypedFloatingPoint {
    var description: String {
        return "float"
    }
}

extension ty.Named {
    var description: String {
        return entity.name
    }
}

extension ty.Metatype {
    var description: String {
        if let instanceType = instanceType as? ty.Tuple, instanceType.types.isEmpty  {
            return "type" // the only possible empty tuple
        }
        return "type(\(instanceType))"
    }
}

extension ty.Polymorphic {
    var description: String {
        return entity.name
    }
}

extension ty.Tuple {
    var description: String {
        return "(" + types.map({ $0.description }).joined(separator: ", ") + ")"
    }
}

extension ty.Invalid {
    var description: String {
        return "< invalid >"
    }
}

extension ty.CVarArg {
    var description: String {
        return "#cvargs ..any"
    }
}

extension ty.File {
    var description: String {
        return "< file >"
    }
}
