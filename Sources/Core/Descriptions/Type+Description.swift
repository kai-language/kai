
extension ty.Void: CustomStringConvertible {
    var description: String {
        return "void"
    }
}

extension ty.Boolean {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "bool"
    }
}

extension ty.Integer {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "\(isSigned ? "i" : "u")\(width!)"
    }
}

extension ty.FloatingPoint {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "f\(width!)"
    }
}

extension ty.KaiString {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "string"
    }
}

extension ty.Pointer {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "*" + pointeeType.description
    }
}

extension ty.Anyy {
    var description: String {
        return "any"
    }
}

extension ty.Struct {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "struct{" + fields.map({ $0.ident.name + ": " + $0.type.description }).joined(separator: ", ") + "}"
    }
}

extension ty.Union {
    var description: String {
        if let name = entity?.name {
            return name
        }

        return "union{" + cases.map({ $0.ident.name + ": " + $0.type.description }).joined(separator: ", ") + "}"
    }
}

extension ty.Variant {
    var description: String {
        if let name = entity?.name {
            return name
        }

        return "variant{" + cases.map({ $0.ident.name + ": " + $0.type.description }).joined(separator: ", ") + "}"
    }
}

extension ty.Enum {
    var description: String {
        if let name = entity?.name {
            return name
        }
        return "enum{" + cases.map({ $0.ident.name + ($0.value.map({ " = " + String(describing: $0) }) ?? "") }).joined(separator: ", ") + "}"
    }
}

extension ty.Array {
    var description: String {
        var str = ""
        if let name = entity?.name {
            str += name + " aka "
        }

        str += "["

        if length != nil {
            str += "\(length!)"
        }

        str += "]" + elementType.description
        return str
    }
}

extension ty.Slice {
    var description: String {
        var str = ""
        if let name = entity?.name {
            str += name + " aka "
        }
        str += "[]" + elementType.description
        return str
    }
}

extension ty.Vector {
    var description: String {
        return "[vec \(size)]" + elementType.description
    }
}

extension ty.Function {
    var description: String {
        var str = ""
        if let name = entity?.name {
            str += name + " aka "
        }
        str += "(" + params.map({ $0.description }).joined(separator: ", ") + ") -> " + returnType.description
        return str
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
