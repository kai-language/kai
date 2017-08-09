// Generated using Sourcery 0.7.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



func copy(_ node: ArrayType) -> ArrayType {
    return ArrayType(
        lbrack: 
        node.lbrack /*Pos*//*e*/
        ,
        length: 
        copy(node.length) /*Expr*//*d*/
        ,
        rbrack: 
        node.rbrack /*Pos*//*e*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [ArrayType]) -> [ArrayType] {
    return nodes.map(copy)
}

func copy(_ node: Assign) -> Assign {
    return Assign(
        lhs: 
        copy(node.lhs) /*[Expr]*//*b*/
        ,
        equals: 
        node.equals /*Pos*//*e*/
        ,
        rhs: 
        copy(node.rhs) /*[Expr]*//*b*/
    )
}

func copy(_ nodes: [Assign]) -> [Assign] {
    return nodes.map(copy)
}

func copy(_ node: BadDecl) -> BadDecl {
    return BadDecl(
        start: 
        node.start /*Pos*//*e*/
        ,
        end: 
        node.end /*Pos*//*e*/
    )
}

func copy(_ nodes: [BadDecl]) -> [BadDecl] {
    return nodes.map(copy)
}

func copy(_ node: BadExpr) -> BadExpr {
    return BadExpr(
        start: 
        node.start /*Pos*//*e*/
        ,
        end: 
        node.end /*Pos*//*e*/
    )
}

func copy(_ nodes: [BadExpr]) -> [BadExpr] {
    return nodes.map(copy)
}

func copy(_ node: BadStmt) -> BadStmt {
    return BadStmt(
        start: 
        node.start /*Pos*//*e*/
        ,
        end: 
        node.end /*Pos*//*e*/
    )
}

func copy(_ nodes: [BadStmt]) -> [BadStmt] {
    return nodes.map(copy)
}

func copy(_ node: BasicLit) -> BasicLit {
    return BasicLit(
        start: 
        node.start /*Pos*//*e*/
        ,
        token: 
        node.token /*Token*//*e*/
        ,
        text: 
        node.text /*String*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
        ,
        value: 
        node.value /*Value!*//*a1*/
    )
}

func copy(_ nodes: [BasicLit]) -> [BasicLit] {
    return nodes.map(copy)
}

func copy(_ node: Binary) -> Binary {
    return Binary(
        lhs: 
        copy(node.lhs) /*Expr*//*d*/
        ,
        op: 
        node.op /*Token*//*e*/
        ,
        opPos: 
        node.opPos /*Pos*//*e*/
        ,
        rhs: 
        copy(node.rhs) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
        ,
        irOp: 
        node.irOp /*OpCode.Binary!*//*a1*/
        ,
        irLCast: 
        node.irLCast /*OpCode.Cast!*//*a1*/
        ,
        irRCast: 
        node.irRCast /*OpCode.Cast!*//*a1*/
    )
}

func copy(_ nodes: [Binary]) -> [Binary] {
    return nodes.map(copy)
}

func copy(_ node: Block) -> Block {
    return Block(
        lbrace: 
        node.lbrace /*Pos*//*e*/
        ,
        stmts: 
        copy(node.stmts) /*[Stmt]*//*b*/
        ,
        rbrace: 
        node.rbrace /*Pos*//*e*/
    )
}

func copy(_ nodes: [Block]) -> [Block] {
    return nodes.map(copy)
}

func copy(_ node: Branch) -> Branch {
    return Branch(
        token: 
        node.token /*Token*//*e*/
        ,
        label: 
        node.label.map(copy) /*Ident?*//*c*/
        ,
        start: 
        node.start /*Pos*//*e*/
    )
}

func copy(_ nodes: [Branch]) -> [Branch] {
    return nodes.map(copy)
}

func copy(_ node: Call) -> Call {
    return Call(
        fun: 
        copy(node.fun) /*Expr*//*d*/
        ,
        lparen: 
        node.lparen /*Pos*//*e*/
        ,
        args: 
        copy(node.args) /*[Expr]*//*b*/
        ,
        rparen: 
        node.rparen /*Pos*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
        ,
        checked: 
        node.checked /*Checked!*//*a1*/
    )
}

func copy(_ nodes: [Call]) -> [Call] {
    return nodes.map(copy)
}

func copy(_ node: CaseClause) -> CaseClause {
    return CaseClause(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        match: 
        node.match.map(copy) /*Expr?*//*c*/
        ,
        colon: 
        node.colon /*Pos*//*e*/
        ,
        block: 
        copy(node.block) /*Block*//*d*/
    )
}

func copy(_ nodes: [CaseClause]) -> [CaseClause] {
    return nodes.map(copy)
}

func copy(_ node: Comment) -> Comment {
    return Comment(
        slash: 
        node.slash /*Pos*//*e*/
        ,
        text: 
        node.text /*String*//*e*/
    )
}

func copy(_ nodes: [Comment]) -> [Comment] {
    return nodes.map(copy)
}

func copy(_ node: CompositeLit) -> CompositeLit {
    return CompositeLit(
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        lbrace: 
        node.lbrace /*Pos*//*e*/
        ,
        elements: 
        copy(node.elements) /*[KeyValue]*//*b*/
        ,
        rbrace: 
        node.rbrace /*Pos*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [CompositeLit]) -> [CompositeLit] {
    return nodes.map(copy)
}

func copy(_ node: DeclBlock) -> DeclBlock {
    return DeclBlock(
        lbrace: 
        node.lbrace /*Pos*//*e*/
        ,
        decls: 
        copy(node.decls) /*[Decl]*//*b*/
        ,
        rbrace: 
        node.rbrace /*Pos*//*e*/
        ,
        callconv: 
        node.callconv /*String?*//*e*/
    )
}

func copy(_ nodes: [DeclBlock]) -> [DeclBlock] {
    return nodes.map(copy)
}

func copy(_ node: Declaration) -> Declaration {
    return Declaration(
        names: 
        copy(node.names) /*[Ident]*//*b*/
        ,
        explicitType: 
        node.explicitType.map(copy) /*Expr?*//*c*/
        ,
        values: 
        copy(node.values) /*[Expr]*//*b*/
        ,
        isConstant: 
        node.isConstant /*Bool*//*e*/
        ,
        callconv: 
        node.callconv /*String?*//*e*/
        ,
        linkname: 
        node.linkname /*String?*//*e*/
        ,
        entities: 
        node.entities /*[Entity]!*//*a1*/
    )
}

func copy(_ nodes: [Declaration]) -> [Declaration] {
    return nodes.map(copy)
}

func copy(_ node: Ellipsis) -> Ellipsis {
    return Ellipsis(
        start: 
        node.start /*Pos*//*e*/
        ,
        element: 
        node.element.map(copy) /*Expr?*//*c*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [Ellipsis]) -> [Ellipsis] {
    return nodes.map(copy)
}

func copy(_ node: Empty) -> Empty {
    return Empty(
        semicolon: 
        node.semicolon /*Pos*//*e*/
        ,
        isImplicit: 
        node.isImplicit /*Bool*//*e*/
    )
}

func copy(_ nodes: [Empty]) -> [Empty] {
    return nodes.map(copy)
}

func copy(_ node: ExprStmt) -> ExprStmt {
    return ExprStmt(
        expr: 
        copy(node.expr) /*Expr*//*d*/
    )
}

func copy(_ nodes: [ExprStmt]) -> [ExprStmt] {
    return nodes.map(copy)
}

func copy(_ node: For) -> For {
    return For(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        initializer: 
        node.initializer.map(copy) /*Stmt?*//*c*/
        ,
        cond: 
        node.cond.map(copy) /*Expr?*//*c*/
        ,
        post: 
        node.post.map(copy) /*Stmt?*//*c*/
        ,
        body: 
        copy(node.body) /*Block*//*d*/
    )
}

func copy(_ nodes: [For]) -> [For] {
    return nodes.map(copy)
}

func copy(_ node: Foreign) -> Foreign {
    return Foreign(
        directive: 
        node.directive /*Pos*//*e*/
        ,
        library: 
        copy(node.library) /*Ident*//*d*/
        ,
        decl: 
        copy(node.decl) /*Decl*//*d*/
        ,
        linkname: 
        node.linkname /*String?*//*e*/
        ,
        callconv: 
        node.callconv /*String?*//*e*/
    )
}

func copy(_ nodes: [Foreign]) -> [Foreign] {
    return nodes.map(copy)
}

func copy(_ node: ForeignFuncLit) -> ForeignFuncLit {
    return ForeignFuncLit(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        params: 
        copy(node.params) /*ParameterList*//*d*/
        ,
        results: 
        copy(node.results) /*ResultList*//*d*/
        ,
        flags: 
        node.flags /*FunctionFlags*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [ForeignFuncLit]) -> [ForeignFuncLit] {
    return nodes.map(copy)
}

func copy(_ node: FuncLit) -> FuncLit {
    return FuncLit(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        params: 
        copy(node.params) /*ParameterList*//*d*/
        ,
        results: 
        copy(node.results) /*ResultList*//*d*/
        ,
        body: 
        copy(node.body) /*Block*//*d*/
        ,
        flags: 
        node.flags /*FunctionFlags*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
        ,
        checked: 
        node.checked /*Checked!*//*a1*/
    )
}

func copy(_ nodes: [FuncLit]) -> [FuncLit] {
    return nodes.map(copy)
}

func copy(_ node: FuncType) -> FuncType {
    return FuncType(
        lparen: 
        node.lparen /*Pos*//*e*/
        ,
        params: 
        copy(node.params) /*[Expr]*//*b*/
        ,
        results: 
        copy(node.results) /*[Expr]*//*b*/
        ,
        flags: 
        node.flags /*FunctionFlags*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [FuncType]) -> [FuncType] {
    return nodes.map(copy)
}

func copy(_ node: Ident) -> Ident {
    return Ident(
        start: 
        node.start /*Pos*//*e*/
        ,
        name: 
        node.name /*String*//*e*/
        ,
        entity: 
        node.entity /*Entity!*//*a1*/
    )
}

func copy(_ nodes: [Ident]) -> [Ident] {
    return nodes.map(copy)
}

func copy(_ node: If) -> If {
    return If(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        cond: 
        copy(node.cond) /*Expr*//*d*/
        ,
        body: 
        copy(node.body) /*Stmt*//*d*/
        ,
        els: 
        node.els.map(copy) /*Stmt?*//*c*/
    )
}

func copy(_ nodes: [If]) -> [If] {
    return nodes.map(copy)
}

func copy(_ node: Import) -> Import {
    return Import(
        directive: 
        node.directive /*Pos*//*e*/
        ,
        path: 
        copy(node.path) /*Expr*//*d*/
        ,
        alias: 
        node.alias.map(copy) /*Ident?*//*c*/
        ,
        importSymbolsIntoScope: 
        node.importSymbolsIntoScope /*Bool*//*e*/
        ,
        resolvedName: 
        node.resolvedName /*String?*//*e*/
        ,
        scope: 
        copy(node.scope) /*Scope!*//*a*/
    )
}

func copy(_ nodes: [Import]) -> [Import] {
    return nodes.map(copy)
}

func copy(_ node: KeyValue) -> KeyValue {
    return KeyValue(
        key: 
        node.key.map(copy) /*Expr?*//*c*/
        ,
        colon: 
        node.colon /*Pos?*//*e*/
        ,
        value: 
        copy(node.value) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [KeyValue]) -> [KeyValue] {
    return nodes.map(copy)
}

func copy(_ node: Label) -> Label {
    return Label(
        label: 
        copy(node.label) /*Ident*//*d*/
        ,
        colon: 
        node.colon /*Pos*//*e*/
    )
}

func copy(_ nodes: [Label]) -> [Label] {
    return nodes.map(copy)
}

func copy(_ node: Library) -> Library {
    return Library(
        directive: 
        node.directive /*Pos*//*e*/
        ,
        path: 
        copy(node.path) /*Expr*//*d*/
        ,
        alias: 
        node.alias.map(copy) /*Ident?*//*c*/
        ,
        resolvedName: 
        node.resolvedName /*String?*//*e*/
    )
}

func copy(_ nodes: [Library]) -> [Library] {
    return nodes.map(copy)
}

func copy(_ node: Parameter) -> Parameter {
    return Parameter(
        dollar: 
        node.dollar /*Pos?*//*e*/
        ,
        name: 
        copy(node.name) /*Ident*//*d*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        entity: 
        node.entity /*Entity!*//*a1*/
    )
}

func copy(_ nodes: [Parameter]) -> [Parameter] {
    return nodes.map(copy)
}

func copy(_ node: ParameterList) -> ParameterList {
    return ParameterList(
        lparen: 
        node.lparen /*Pos*//*e*/
        ,
        list: 
        copy(node.list) /*[Parameter]*//*b*/
        ,
        rparen: 
        node.rparen /*Pos*//*e*/
    )
}

func copy(_ nodes: [ParameterList]) -> [ParameterList] {
    return nodes.map(copy)
}

func copy(_ node: Paren) -> Paren {
    return Paren(
        lparen: 
        node.lparen /*Pos*//*e*/
        ,
        element: 
        copy(node.element) /*Expr*//*d*/
        ,
        rparen: 
        node.rparen /*Pos*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [Paren]) -> [Paren] {
    return nodes.map(copy)
}

func copy(_ node: PointerType) -> PointerType {
    return PointerType(
        star: 
        node.star /*Pos*//*e*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [PointerType]) -> [PointerType] {
    return nodes.map(copy)
}

func copy(_ node: PolyType) -> PolyType {
    return PolyType(
        dollar: 
        node.dollar /*Pos*//*e*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [PolyType]) -> [PolyType] {
    return nodes.map(copy)
}

func copy(_ node: ResultList) -> ResultList {
    return ResultList(
        lparen: 
        node.lparen /*Pos?*//*e*/
        ,
        types: 
        copy(node.types) /*[Expr]*//*b*/
        ,
        rparen: 
        node.rparen /*Pos?*//*e*/
    )
}

func copy(_ nodes: [ResultList]) -> [ResultList] {
    return nodes.map(copy)
}

func copy(_ node: Return) -> Return {
    return Return(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        results: 
        copy(node.results) /*[Expr]*//*b*/
    )
}

func copy(_ nodes: [Return]) -> [Return] {
    return nodes.map(copy)
}

func copy(_ node: Selector) -> Selector {
    return Selector(
        rec: 
        copy(node.rec) /*Expr*//*d*/
        ,
        sel: 
        copy(node.sel) /*Ident*//*d*/
        ,
        checked: 
        node.checked /*Checked!*//*a1*/
    )
}

func copy(_ nodes: [Selector]) -> [Selector] {
    return nodes.map(copy)
}

func copy(_ node: SliceType) -> SliceType {
    return SliceType(
        lbrack: 
        node.lbrack /*Pos*//*e*/
        ,
        rbrack: 
        node.rbrack /*Pos*//*e*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [SliceType]) -> [SliceType] {
    return nodes.map(copy)
}

func copy(_ node: StructField) -> StructField {
    return StructField(
        names: 
        copy(node.names) /*[Ident]*//*b*/
        ,
        colon: 
        node.colon /*Pos*//*e*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [StructField]) -> [StructField] {
    return nodes.map(copy)
}

func copy(_ node: StructType) -> StructType {
    return StructType(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        lbrace: 
        node.lbrace /*Pos*//*e*/
        ,
        fields: 
        copy(node.fields) /*[StructField]*//*b*/
        ,
        rbrace: 
        node.rbrace /*Pos*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [StructType]) -> [StructType] {
    return nodes.map(copy)
}

func copy(_ node: Switch) -> Switch {
    return Switch(
        keyword: 
        node.keyword /*Pos*//*e*/
        ,
        match: 
        node.match.map(copy) /*Expr?*//*c*/
        ,
        block: 
        copy(node.block) /*Block*//*d*/
    )
}

func copy(_ nodes: [Switch]) -> [Switch] {
    return nodes.map(copy)
}

func copy(_ node: Ternary) -> Ternary {
    return Ternary(
        cond: 
        copy(node.cond) /*Expr*//*d*/
        ,
        qmark: 
        node.qmark /*Pos*//*e*/
        ,
        then: 
        node.then.map(copy) /*Expr?*//*c*/
        ,
        colon: 
        node.colon /*Pos*//*e*/
        ,
        els: 
        copy(node.els) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [Ternary]) -> [Ternary] {
    return nodes.map(copy)
}

func copy(_ node: Unary) -> Unary {
    return Unary(
        start: 
        node.start /*Pos*//*e*/
        ,
        op: 
        node.op /*Token*//*e*/
        ,
        element: 
        copy(node.element) /*Expr*//*d*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [Unary]) -> [Unary] {
    return nodes.map(copy)
}

func copy(_ node: VariadicType) -> VariadicType {
    return VariadicType(
        ellipsis: 
        node.ellipsis /*Pos*//*e*/
        ,
        explicitType: 
        copy(node.explicitType) /*Expr*//*d*/
        ,
        isCvargs: 
        node.isCvargs /*Bool*//*e*/
        ,
        type: 
        node.type /*Type!*//*a1*/
    )
}

func copy(_ nodes: [VariadicType]) -> [VariadicType] {
    return nodes.map(copy)
}

func copy(_ node: Expr) -> Expr {
    switch node {
    case let node as ArrayType: return copy(node)
    case let node as BadExpr: return copy(node)
    case let node as BasicLit: return copy(node)
    case let node as Binary: return copy(node)
    case let node as Call: return copy(node)
    case let node as CompositeLit: return copy(node)
    case let node as Ellipsis: return copy(node)
    case let node as ForeignFuncLit: return copy(node)
    case let node as FuncLit: return copy(node)
    case let node as FuncType: return copy(node)
    case let node as Ident: return copy(node)
    case let node as KeyValue: return copy(node)
    case let node as Parameter: return copy(node)
    case let node as Paren: return copy(node)
    case let node as PointerType: return copy(node)
    case let node as PolyType: return copy(node)
    case let node as Selector: return copy(node)
    case let node as SliceType: return copy(node)
    case let node as StructType: return copy(node)
    case let node as Ternary: return copy(node)
    case let node as Unary: return copy(node)
    case let node as VariadicType: return copy(node)
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
    case let node as Empty: return copy(node)
    case let node as ExprStmt: return copy(node)
    case let node as For: return copy(node)
    case let node as Foreign: return copy(node)
    case let node as If: return copy(node)
    case let node as Import: return copy(node)
    case let node as Label: return copy(node)
    case let node as Library: return copy(node)
    case let node as Return: return copy(node)
    case let node as Switch: return copy(node)
    default: fatalError()
    }
}

func copy(_ nodes: [Stmt]) -> [Stmt] {
    return nodes.map(copy)
}

func copy(_ node: Decl) -> Decl {
    switch node {
    case let node as BadDecl: return copy(node)
    case let node as DeclBlock: return copy(node)
    case let node as Declaration: return copy(node)
    case let node as Foreign: return copy(node)
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
        members: scope.members.map(copy)
    )
}

func copy(_ entity: Entity) -> Entity {
    return Entity(
        ident: entity.ident,
        type: entity.type,
        flags: entity.flags,
        memberScope: entity.memberScope,
        owningScope: entity.owningScope,
        value: entity.value
    )
}

