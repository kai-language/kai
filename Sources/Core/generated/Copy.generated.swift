// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



func copy(_ node: ArrayType) -> ArrayType {
    return ArrayType(
        lbrack: node.lbrack,
        length: node.length.map(copy),
        rbrack: node.rbrack,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [ArrayType]) -> [ArrayType] {
    return nodes.map(copy)
}

func copy(_ node: Assign) -> Assign {
    return Assign(
        lhs: copy(node.lhs),
        equals: node.equals,
        rhs: copy(node.rhs)
    )
}

func copy(_ nodes: [Assign]) -> [Assign] {
    return nodes.map(copy)
}

func copy(_ node: Autocast) -> Autocast {
    return Autocast(
        keyword: node.keyword,
        expr: copy(node.expr),
        type: node.type,
        op: node.op
    )
}

func copy(_ nodes: [Autocast]) -> [Autocast] {
    return nodes.map(copy)
}

func copy(_ node: BadDecl) -> BadDecl {
    return BadDecl(
        start: node.start,
        end: node.end
    )
}

func copy(_ nodes: [BadDecl]) -> [BadDecl] {
    return nodes.map(copy)
}

func copy(_ node: BadExpr) -> BadExpr {
    return BadExpr(
        start: node.start,
        end: node.end
    )
}

func copy(_ nodes: [BadExpr]) -> [BadExpr] {
    return nodes.map(copy)
}

func copy(_ node: BadStmt) -> BadStmt {
    return BadStmt(
        start: node.start,
        end: node.end
    )
}

func copy(_ nodes: [BadStmt]) -> [BadStmt] {
    return nodes.map(copy)
}

func copy(_ node: BasicLit) -> BasicLit {
    return BasicLit(
        start: node.start,
        token: node.token,
        text: node.text,
        type: node.type,
        constant: node.constant
    )
}

func copy(_ nodes: [BasicLit]) -> [BasicLit] {
    return nodes.map(copy)
}

func copy(_ node: Binary) -> Binary {
    return Binary(
        lhs: copy(node.lhs),
        op: node.op,
        opPos: node.opPos,
        rhs: copy(node.rhs),
        type: node.type,
        irOp: node.irOp,
        irLCast: node.irLCast,
        irRCast: node.irRCast,
        isPointerArithmetic: node.isPointerArithmetic
    )
}

func copy(_ nodes: [Binary]) -> [Binary] {
    return nodes.map(copy)
}

func copy(_ node: Block) -> Block {
    return Block(
        lbrace: node.lbrace,
        stmts: copy(node.stmts),
        rbrace: node.rbrace
    )
}

func copy(_ nodes: [Block]) -> [Block] {
    return nodes.map(copy)
}

func copy(_ node: Branch) -> Branch {
    return Branch(
        token: node.token,
        label: node.label.map(copy),
        target: node.target,
        start: node.start
    )
}

func copy(_ nodes: [Branch]) -> [Branch] {
    return nodes.map(copy)
}

func copy(_ node: Call) -> Call {
    return Call(
        fun: copy(node.fun),
        lparen: node.lparen,
        args: copy(node.args),
        rparen: node.rparen,
        type: node.type,
        checked: node.checked
    )
}

func copy(_ nodes: [Call]) -> [Call] {
    return nodes.map(copy)
}

func copy(_ node: CaseClause) -> CaseClause {
    return CaseClause(
        keyword: node.keyword,
        match: node.match.map(copy),
        colon: node.colon,
        block: copy(node.block),
        label: node.label
    )
}

func copy(_ nodes: [CaseClause]) -> [CaseClause] {
    return nodes.map(copy)
}

func copy(_ node: Cast) -> Cast {
    return Cast(
        keyword: node.keyword,
        kind: node.kind,
        explicitType: copy(node.explicitType),
        expr: copy(node.expr),
        type: node.type,
        op: node.op
    )
}

func copy(_ nodes: [Cast]) -> [Cast] {
    return nodes.map(copy)
}

func copy(_ node: Comment) -> Comment {
    return Comment(
        slash: node.slash,
        text: node.text
    )
}

func copy(_ nodes: [Comment]) -> [Comment] {
    return nodes.map(copy)
}

func copy(_ node: CompositeLit) -> CompositeLit {
    return CompositeLit(
        explicitType: node.explicitType.map(copy),
        lbrace: node.lbrace,
        elements: copy(node.elements),
        rbrace: node.rbrace,
        type: node.type
    )
}

func copy(_ nodes: [CompositeLit]) -> [CompositeLit] {
    return nodes.map(copy)
}

func copy(_ node: DeclBlock) -> DeclBlock {
    return DeclBlock(
        lbrace: node.lbrace,
        decls: copy(node.decls),
        rbrace: node.rbrace,
        isForeign: node.isForeign,
        linkprefix: node.linkprefix,
        callconv: node.callconv,
        dependsOn: node.dependsOn,
        emitted: node.emitted
    )
}

func copy(_ nodes: [DeclBlock]) -> [DeclBlock] {
    return nodes.map(copy)
}

func copy(_ node: Declaration) -> Declaration {
    return Declaration(
        names: copy(node.names),
        explicitType: node.explicitType.map(copy),
        values: copy(node.values),
        isConstant: node.isConstant,
        callconv: node.callconv,
        linkname: node.linkname,
        entities: node.entities,
        dependsOn: node.dependsOn,
        emitted: node.emitted
    )
}

func copy(_ nodes: [Declaration]) -> [Declaration] {
    return nodes.map(copy)
}

func copy(_ node: Defer) -> Defer {
    return Defer(
        keyword: node.keyword,
        stmt: copy(node.stmt)
    )
}

func copy(_ nodes: [Defer]) -> [Defer] {
    return nodes.map(copy)
}

func copy(_ node: DynamicArrayType) -> DynamicArrayType {
    return DynamicArrayType(
        lbrack: node.lbrack,
        rbrack: node.rbrack,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [DynamicArrayType]) -> [DynamicArrayType] {
    return nodes.map(copy)
}

func copy(_ node: Ellipsis) -> Ellipsis {
    return Ellipsis(
        start: node.start,
        element: node.element.map(copy),
        type: node.type
    )
}

func copy(_ nodes: [Ellipsis]) -> [Ellipsis] {
    return nodes.map(copy)
}

func copy(_ node: Empty) -> Empty {
    return Empty(
        semicolon: node.semicolon,
        isImplicit: node.isImplicit
    )
}

func copy(_ nodes: [Empty]) -> [Empty] {
    return nodes.map(copy)
}

func copy(_ node: EnumCase) -> EnumCase {
    return EnumCase(
        name: copy(node.name),
        value: node.value.map(copy)
    )
}

func copy(_ nodes: [EnumCase]) -> [EnumCase] {
    return nodes.map(copy)
}

func copy(_ node: EnumType) -> EnumType {
    return EnumType(
        keyword: node.keyword,
        explicitType: node.explicitType.map(copy),
        cases: copy(node.cases),
        rbrace: node.rbrace,
        type: node.type
    )
}

func copy(_ nodes: [EnumType]) -> [EnumType] {
    return nodes.map(copy)
}

func copy(_ node: ExprStmt) -> ExprStmt {
    return ExprStmt(
        expr: copy(node.expr)
    )
}

func copy(_ nodes: [ExprStmt]) -> [ExprStmt] {
    return nodes.map(copy)
}

func copy(_ node: For) -> For {
    return For(
        keyword: node.keyword,
        initializer: node.initializer.map(copy),
        cond: node.cond.map(copy),
        step: node.step.map(copy),
        body: copy(node.body),
        breakLabel: node.breakLabel,
        continueLabel: node.continueLabel
    )
}

func copy(_ nodes: [For]) -> [For] {
    return nodes.map(copy)
}

func copy(_ node: ForIn) -> ForIn {
    return ForIn(
        keyword: node.keyword,
        names: copy(node.names),
        aggregate: copy(node.aggregate),
        body: copy(node.body),
        breakLabel: node.breakLabel,
        continueLabel: node.continueLabel,
        element: node.element,
        index: node.index,
        checked: node.checked
    )
}

func copy(_ nodes: [ForIn]) -> [ForIn] {
    return nodes.map(copy)
}

func copy(_ node: Foreign) -> Foreign {
    return Foreign(
        directive: node.directive,
        library: copy(node.library),
        decl: copy(node.decl),
        linkname: node.linkname,
        callconv: node.callconv,
        dependsOn: node.dependsOn,
        emitted: node.emitted
    )
}

func copy(_ nodes: [Foreign]) -> [Foreign] {
    return nodes.map(copy)
}

func copy(_ node: FuncLit) -> FuncLit {
    return FuncLit(
        keyword: node.keyword,
        params: copy(node.params),
        results: copy(node.results),
        body: copy(node.body),
        flags: node.flags,
        type: node.type,
        checked: node.checked
    )
}

func copy(_ nodes: [FuncLit]) -> [FuncLit] {
    return nodes.map(copy)
}

func copy(_ node: FuncType) -> FuncType {
    return FuncType(
        lparen: node.lparen,
        params: copy(node.params),
        results: copy(node.results),
        flags: node.flags,
        type: node.type
    )
}

func copy(_ nodes: [FuncType]) -> [FuncType] {
    return nodes.map(copy)
}

func copy(_ node: Ident) -> Ident {
    return Ident(
        start: node.start,
        name: node.name,
        entity: node.entity,
        type: node.type,
        cast: node.cast,
        constant: node.constant
    )
}

func copy(_ nodes: [Ident]) -> [Ident] {
    return nodes.map(copy)
}

func copy(_ node: IdentList) -> IdentList {
    return IdentList(
        idents: copy(node.idents)
    )
}

func copy(_ nodes: [IdentList]) -> [IdentList] {
    return nodes.map(copy)
}

func copy(_ node: If) -> If {
    return If(
        keyword: node.keyword,
        cond: copy(node.cond),
        body: copy(node.body),
        els: node.els.map(copy)
    )
}

func copy(_ nodes: [If]) -> [If] {
    return nodes.map(copy)
}

func copy(_ node: Import) -> Import {
    return Import(
        directive: node.directive,
        alias: node.alias.map(copy),
        path: copy(node.path),
        importSymbolsIntoScope: node.importSymbolsIntoScope,
        exportSymbolsOutOfScope: node.exportSymbolsOutOfScope,
        resolvedName: node.resolvedName,
        scope: copy(node.scope)
    )
}

func copy(_ nodes: [Import]) -> [Import] {
    return nodes.map(copy)
}

func copy(_ node: KeyValue) -> KeyValue {
    return KeyValue(
        key: node.key.map(copy),
        colon: node.colon,
        value: copy(node.value),
        type: node.type,
        structField: node.structField
    )
}

func copy(_ nodes: [KeyValue]) -> [KeyValue] {
    return nodes.map(copy)
}

func copy(_ node: Label) -> Label {
    return Label(
        label: copy(node.label),
        colon: node.colon
    )
}

func copy(_ nodes: [Label]) -> [Label] {
    return nodes.map(copy)
}

func copy(_ node: Library) -> Library {
    return Library(
        directive: node.directive,
        path: copy(node.path),
        alias: node.alias.map(copy),
        resolvedName: node.resolvedName
    )
}

func copy(_ nodes: [Library]) -> [Library] {
    return nodes.map(copy)
}

func copy(_ node: Nil) -> Nil {
    return Nil(
        start: node.start,
        type: node.type
    )
}

func copy(_ nodes: [Nil]) -> [Nil] {
    return nodes.map(copy)
}

func copy(_ node: Parameter) -> Parameter {
    return Parameter(
        dollar: node.dollar,
        name: copy(node.name),
        explicitType: copy(node.explicitType),
        entity: node.entity
    )
}

func copy(_ nodes: [Parameter]) -> [Parameter] {
    return nodes.map(copy)
}

func copy(_ node: ParameterList) -> ParameterList {
    return ParameterList(
        lparen: node.lparen,
        list: copy(node.list),
        rparen: node.rparen
    )
}

func copy(_ nodes: [ParameterList]) -> [ParameterList] {
    return nodes.map(copy)
}

func copy(_ node: Paren) -> Paren {
    return Paren(
        lparen: node.lparen,
        element: copy(node.element),
        rparen: node.rparen
    )
}

func copy(_ nodes: [Paren]) -> [Paren] {
    return nodes.map(copy)
}

func copy(_ node: PointerType) -> PointerType {
    return PointerType(
        star: node.star,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [PointerType]) -> [PointerType] {
    return nodes.map(copy)
}

func copy(_ node: PolyParameterList) -> PolyParameterList {
    return PolyParameterList(
        lparen: node.lparen,
        list: copy(node.list),
        rparen: node.rparen
    )
}

func copy(_ nodes: [PolyParameterList]) -> [PolyParameterList] {
    return nodes.map(copy)
}

func copy(_ node: PolyStructType) -> PolyStructType {
    return PolyStructType(
        lbrace: node.lbrace,
        polyTypes: copy(node.polyTypes),
        fields: copy(node.fields),
        rbrace: node.rbrace,
        type: node.type
    )
}

func copy(_ nodes: [PolyStructType]) -> [PolyStructType] {
    return nodes.map(copy)
}

func copy(_ node: PolyType) -> PolyType {
    return PolyType(
        dollar: node.dollar,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [PolyType]) -> [PolyType] {
    return nodes.map(copy)
}

func copy(_ node: ResultList) -> ResultList {
    return ResultList(
        lparen: node.lparen,
        types: copy(node.types),
        rparen: node.rparen
    )
}

func copy(_ nodes: [ResultList]) -> [ResultList] {
    return nodes.map(copy)
}

func copy(_ node: Return) -> Return {
    return Return(
        keyword: node.keyword,
        results: copy(node.results)
    )
}

func copy(_ nodes: [Return]) -> [Return] {
    return nodes.map(copy)
}

func copy(_ node: Selector) -> Selector {
    return Selector(
        rec: copy(node.rec),
        sel: copy(node.sel),
        checked: node.checked,
        type: node.type,
        cast: node.cast,
        constant: node.constant
    )
}

func copy(_ nodes: [Selector]) -> [Selector] {
    return nodes.map(copy)
}

func copy(_ node: SliceType) -> SliceType {
    return SliceType(
        lbrack: node.lbrack,
        rbrack: node.rbrack,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [SliceType]) -> [SliceType] {
    return nodes.map(copy)
}

func copy(_ node: StructField) -> StructField {
    return StructField(
        names: copy(node.names),
        colon: node.colon,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [StructField]) -> [StructField] {
    return nodes.map(copy)
}

func copy(_ node: StructType) -> StructType {
    return StructType(
        keyword: node.keyword,
        lbrace: node.lbrace,
        fields: copy(node.fields),
        rbrace: node.rbrace,
        type: node.type,
        checked: node.checked
    )
}

func copy(_ nodes: [StructType]) -> [StructType] {
    return nodes.map(copy)
}

func copy(_ node: Subscript) -> Subscript {
    return Subscript(
        rec: copy(node.rec),
        index: copy(node.index),
        type: node.type,
        checked: node.checked
    )
}

func copy(_ nodes: [Subscript]) -> [Subscript] {
    return nodes.map(copy)
}

func copy(_ node: Switch) -> Switch {
    return Switch(
        keyword: node.keyword,
        match: node.match.map(copy),
        cases: copy(node.cases),
        rbrace: node.rbrace,
        label: node.label
    )
}

func copy(_ nodes: [Switch]) -> [Switch] {
    return nodes.map(copy)
}

func copy(_ node: Ternary) -> Ternary {
    return Ternary(
        cond: copy(node.cond),
        qmark: node.qmark,
        then: node.then.map(copy),
        colon: node.colon,
        els: copy(node.els),
        type: node.type
    )
}

func copy(_ nodes: [Ternary]) -> [Ternary] {
    return nodes.map(copy)
}

func copy(_ node: Unary) -> Unary {
    return Unary(
        start: node.start,
        op: node.op,
        element: copy(node.element),
        type: node.type
    )
}

func copy(_ nodes: [Unary]) -> [Unary] {
    return nodes.map(copy)
}

func copy(_ node: UnionType) -> UnionType {
    return UnionType(
        keyword: node.keyword,
        lbrace: node.lbrace,
        fields: copy(node.fields),
        rbrace: node.rbrace,
        type: node.type
    )
}

func copy(_ nodes: [UnionType]) -> [UnionType] {
    return nodes.map(copy)
}

func copy(_ node: Using) -> Using {
    return Using(
        keyword: node.keyword,
        expr: copy(node.expr)
    )
}

func copy(_ nodes: [Using]) -> [Using] {
    return nodes.map(copy)
}

func copy(_ node: VariadicType) -> VariadicType {
    return VariadicType(
        ellipsis: node.ellipsis,
        explicitType: copy(node.explicitType),
        isCvargs: node.isCvargs,
        type: node.type
    )
}

func copy(_ nodes: [VariadicType]) -> [VariadicType] {
    return nodes.map(copy)
}

func copy(_ node: VariantType) -> VariantType {
    return VariantType(
        keyword: node.keyword,
        lbrace: node.lbrace,
        fields: copy(node.fields),
        rbrace: node.rbrace,
        type: node.type
    )
}

func copy(_ nodes: [VariantType]) -> [VariantType] {
    return nodes.map(copy)
}

func copy(_ node: VectorType) -> VectorType {
    return VectorType(
        lbrack: node.lbrack,
        size: copy(node.size),
        rbrack: node.rbrack,
        explicitType: copy(node.explicitType),
        type: node.type
    )
}

func copy(_ nodes: [VectorType]) -> [VectorType] {
    return nodes.map(copy)
}

func copy(_ node: Expr) -> Expr {
    switch node {
    case let node as ArrayType: return copy(node)
    case let node as Autocast: return copy(node)
    case let node as BadExpr: return copy(node)
    case let node as BasicLit: return copy(node)
    case let node as Binary: return copy(node)
    case let node as Call: return copy(node)
    case let node as Cast: return copy(node)
    case let node as CompositeLit: return copy(node)
    case let node as DynamicArrayType: return copy(node)
    case let node as Ellipsis: return copy(node)
    case let node as EnumType: return copy(node)
    case let node as FuncLit: return copy(node)
    case let node as FuncType: return copy(node)
    case let node as Ident: return copy(node)
    case let node as KeyValue: return copy(node)
    case let node as Nil: return copy(node)
    case let node as Paren: return copy(node)
    case let node as PointerType: return copy(node)
    case let node as PolyStructType: return copy(node)
    case let node as PolyType: return copy(node)
    case let node as Selector: return copy(node)
    case let node as SliceType: return copy(node)
    case let node as StructType: return copy(node)
    case let node as Subscript: return copy(node)
    case let node as Ternary: return copy(node)
    case let node as Unary: return copy(node)
    case let node as UnionType: return copy(node)
    case let node as VariadicType: return copy(node)
    case let node as VariantType: return copy(node)
    case let node as VectorType: return copy(node)
    default: fatalError()
    }
}

func copy(_ nodes: [Expr]) -> [Expr] {
    return nodes.map(copy)
}

func copy(_ node: Stmt) -> Stmt {
    switch node {
    case let node as Assign: return copy(node)
    case let node as BadDecl: return copy(node)
    case let node as BadStmt: return copy(node)
    case let node as Block: return copy(node)
    case let node as Branch: return copy(node)
    case let node as CaseClause: return copy(node)
    case let node as DeclBlock: return copy(node)
    case let node as Declaration: return copy(node)
    case let node as Defer: return copy(node)
    case let node as Empty: return copy(node)
    case let node as ExprStmt: return copy(node)
    case let node as For: return copy(node)
    case let node as ForIn: return copy(node)
    case let node as Foreign: return copy(node)
    case let node as IdentList: return copy(node)
    case let node as If: return copy(node)
    case let node as Import: return copy(node)
    case let node as Label: return copy(node)
    case let node as Library: return copy(node)
    case let node as Return: return copy(node)
    case let node as Switch: return copy(node)
    case let node as Using: return copy(node)
    default: fatalError()
    }
}

func copy(_ nodes: [Stmt]) -> [Stmt] {
    return nodes.map(copy)
}

func copy(_ node: Decl) -> Decl {
    switch node {
    case let node as BadDecl: return copy(node)
    case let node as Declaration: return copy(node)
    default: fatalError()
    }
}

func copy(_ nodes: [Decl]) -> [Decl] {
    return nodes.map(copy)
}

func copy(_ scope: Scope) -> Scope {
    return Scope(
        parent: scope.parent,
        owningNode: scope.owningNode,
        isFile: scope.isFile,
        isPackage: scope.isPackage,
        members: scope.members.mapValues(copy)
    )
}

func copy(_ entity: Entity) -> Entity {
    return Entity(
        ident: entity.ident,
        type: entity.type,
        flags: entity.flags,
        constant: entity.constant,
        package: entity.package,
        memberScope: entity.memberScope,
        owningScope: entity.owningScope,
        callconv: entity.callconv,
        linkname: entity.linkname,
        mangledName: nil,
        value: nil
    )
}

