
enum SemanticPass: Pass {

    static let name: String = "Semantic Analysis"

    static var totalTime: Double = 0

    static let validators: [ASTValidator.Type] = []

    static func run(_ node: AST.Node) throws {

        for validator in SemanticPass.validators {
            try validator.run(node)
        }

        for child in node.children {
            try SemanticPass.run(child)
        }
    }

    static func run(_ node: AST.Node, options: ASTValidatorOption) throws {

        for validator in SemanticPass.validators {
            try validator.run(node, options: options)
        }

        for child in node.children {
            try SemanticPass.run(child, options: options)
        }
    }
}
