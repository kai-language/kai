
# Lexemes

    ident
    intLit
    floatLit
    stringLit
    unaryOp
    binaryOp

# Common Constructs

    IdentList = ident { "," ident } .
    ExprList  = Expr { "," Expr } .
    TypeList  = Type { "," Type } .
    StmtList  = { Stmt ";" } .
    Block     = "{" StmtList "}" .

# Expressions

    Expr        = UnaryExpr | BinaryExpr | TernaryExpr .
    UnaryExpr   = PrimaryExpr | unaryOp UnaryExpr .
    BinaryExpr  = Expr binaryOp Expr .
    TernaryExpr = Expr "?" [ Expr ] ":" Expr .
    PrimaryExpr = Operand | Operand Selector | Operand Call .
    Operand     = ident | Literal | "(" Expr ")" | Type .

    Literal = BasicLit | CompositeLit | FuncLit .
    BasicLit = intLit | floatLit | stringLit .

    Selector = "." ident .
    Call     = "(" [ ExprList ] ")" .

## Type

    Type        = ident | ArrayType | PointerType | FuncType | StructType .
    ArrayType   = "[" Expr "]" Type .
    PointerType = "*" Type .

    FuncType           = "(" [ FuncParameterList ] ")" "->" TypeOrPolyTypeList .
    ParameterTypeList  = TypeOrPolyTypeList [ "," VariadicType ] .
    TypeOrPolyTypeList = TypeOrPolyType { "," TypeOrPolyType } .
    TypeOrPolyType     = ( Type | PolyType ) .
    PolyType           = "$" Type .
    VariadicType       = [ "#cvargs" ] ".." TypeOrPolyType .

    StructType      = "struct" "{" StructFieldList "}" .
    StructFieldList = "{" StructFieldDecl { ","  StructFieldDecl } "}" .
    StructFieldDecl = IdentList ":" Expr .

## Function Literals

    FuncLit   = "fn" Signature Block .
    Signature = "(" [ ParameterList ] ")" "->" ResultList .

    ParameterList        = Parameter { "," Parameter } [ [ "#cvargs" ".."  ] .
    Parameter            = ParameterNameList ":" TypeOrPolyType .
    ParameterNameList    = ParameterName { "," ParameterName } .
    ParameterName        = ( ident | PolymorphicParameter ) .
    PolymorphicParameter = "$" ident .
    ResultList           = ( LabeledResults | TypeOrPolyTypeList ) .
    LabeledResults       = "(" Result { "," Result } ")" .
    Result               = ( LabeledResult | TypeOrPolyType ) .
    LabeledResult        = ident ":" TypeOrPolyType .

## Composite Literals

    CompositeLit      = CompositeLitType CompositeLitValue .
    CompositeLitType  = ( Type | "[" ".." "]" Type ) .
    CompositeLitValue = "{" [ ElementList [ "," ] ] "}" .
    ElementList       = Element { "," Element } .
    Element           = KeyedElement | Expr .
    KeyedElement      = ident ":" Expr .

# Declarations

    Decl          = [ DeclDirectiveList ] ( VarDecl | UninitVarDecl | ValDecl ) .
    VarDecl       = IdentList ":" [ Type ] "=" ExprList .
    UninitVarDecl = IdentList ":" Type .
    ValDecl       = IdentList ":" [ Type ] ":" ExprList .

# Statements

    Stmt = SimpleStmt | Decl | Label |
        Return | Break | Continue | Goto | Fallthrough |
        If | Switch | For | Defer | Block .

    SimpleStmt = EmptyStmt | ExprStmt | Assign .

    Assign = ( ExprList assignOp ExprList | AssignMacro ) .
    AssignMacro = binOp assignOp Expr .

    EmptyStmt = .
    Label     = ident ":" .

    Return      = "return" [ ExprList ] .
    Break       = "break" [ ident ] .
    Continue    = "continue" [ ident ] .
    Goto        = "goto" ident .
    Fallthrough = "fallthrough" .

    If = "if" Expr Stmt [ "else" Stmt ] .

    Switch     = "switch" [ Expr ] "{" { CaseClause } "}" .
    CaseClause = "case" [ ExprList ] ":" StmtList .

    For       = "for" [ Expr | ForClause ] Block .
    ForClause = [ SimpleStmt ] ";" [ Expr ] ";" [ SimpleStmt ] .

    Defer = "defer" Stmt .

# Directives

    Import  = "#import" Expr [ ident | "." ] .
    Library = "#library" Expr [ ident ] .

    Foreign         = "#foreign" LibName ( ForeignBlock | ForeignDecl ) .
    ForeignBlock    = "{" { ForeignDecl Term } "}" .
    ForeignDecl     = [ DeclDirectivesList ] ( ForeignFuncDecl | UninitVarDecl ) .
    ForeignFuncDecl = "fn" ( Signature | FuncType ) .

    DeclDirectiveList = DeclDirective { DeclDirective } .
    DeclDirective     = ( Linkname | CallConv | Discardable ) .
    Linkname          = "#linkname" stringLit .
    CallConv          = "#callconv" stringLit .
    Discardable       = "#discardable" .

