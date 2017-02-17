struct Constraint {
	var lhs: KaiType
	var rhs: KaiType
	var kind: Kind

	enum Kind {
		case equality
	}
}