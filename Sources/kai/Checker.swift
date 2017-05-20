import Foundation
import OrderedDictionary

/// Defines a type in which something can take
class Type: Equatable, CustomStringConvertible {

    var kind: Kind
    var flags: Flag

    /// Size of the type (in bits)
    var width: UInt
    var location: SourceLocation?

    init(kind: Kind, flags: Flag = .none, width: UInt, location: SourceLocation? = nil) {
        self.kind = kind
        self.flags = flags
        self.width = width
        self.location = location
    }

    enum Kind {
        // These are all special cases of the named Type.
        case builtin(String)
        case named(Entity)
        case alias(Type, Entity)
        case `struct`(Scope)
        case `enum`(Scope)
        
        case pointer(underlyingType: Type)
        case nullablePointer(underlyingType: Type)
        case array(underlyingType: Type, count: UInt)
        case proc(params: [Entity], returns: [Type], isVariadic: Bool)

        /// Only used for multiple returns.
        case tuple([Type])

        case type(Type)
    }

    var instance: Type? {

        if self === Type.invalid {
            return self
        }

        if self === Type.typeInfo {
            return Type.typeInfo
        }

        switch self.kind {
        case .type(let instanceType):
            return instanceType

        // FIXME(vdka): the hell do we do here?
        case .builtin(_):
            return self
            
        default:
            return nil
        }
    }
    
    var underlyingType: Type? {
        switch self.kind {
        case .named(let entity):
            return entity.type!.underlyingType

        case .alias(let type, _):
            return type

        case .pointer(let underlyingType),
             .nullablePointer(let underlyingType),
             .array(let underlyingType, _):
            return underlyingType

        case .builtin, .struct, .proc, .tuple, .enum:
            return nil

        case .type(let type):
            return type
        }
    }

    var memberScope: Scope? {
        switch self.kind {
        case .named(let entity):
            return entity.type!.memberScope

        case .alias(let type, _):
            return type.memberScope

        case .struct(let memberScope),
             .enum(let memberScope):
            return memberScope

        case .type(let type):

            // FIXME
            // FIXME
            // FIXME
            // FIXME(vdka): Access the scope returned *must* only contain members on the Type itself.
            //   Currently memberscope here includes both `::` & `:=` declarations, where `:=` should 
            //   be only available on an instance of the type and `::` on the Type itself
            return type.memberScope

        case .pointer(let underlyingType),
             .nullablePointer(let underlyingType):
            return underlyingType.memberScope

        case .builtin,
             .proc, .tuple, .array:
            return nil
        }
    }

    static func alias(of type: Type, with entity: Entity) -> Type {

        return Type(kind: .alias(type, entity), flags: .none, width: type.width, location: entity.location)
    }

    static func named(_ entity: Entity) -> Type {
        if entity.type == Type.invalid {
            return Type.invalid
        }
        return Type(kind: .named(entity), flags: .none, width: entity.type!.width, location: entity.location)
    }

    static func pointer(to underlyingType: Type) -> Type {
        if underlyingType == Type.invalid {
            return Type.invalid
        }
        return Type(kind: .pointer(underlyingType: underlyingType), flags: .pointer, width: UInt(MemoryLayout<Int>.size * 8), location: nil)
    }

    static func nullablePointer(to underlyingType: Type) -> Type {
        if underlyingType == Type.invalid {
            return Type.invalid
        }
        return Type(kind: .nullablePointer(underlyingType: underlyingType), flags: .pointer, width: UInt(MemoryLayout<Int>.size * 8), location: nil)
    }

    static func array(of underlyingType: Type, with count: UInt) -> Type {
        if underlyingType == Type.invalid {
            return Type.invalid
        }
        // NOTE(vdka): Size may not be correct with alignments and paddings?
        return Type(kind: .array(underlyingType: underlyingType, count: count), flags: .none, width: underlyingType.width * count, location: nil)
    }

    static func tuple(of types: [Type]) -> Type {
        // NOTE(vdka): Size may not be correct with alignments and paddings?
        return Type(kind: .tuple(types), flags: .none, width: types.reduce(0, { $0.0 + $0.1.width }), location: nil)
    }
    
    static func integer(bits: Int) -> Type {
        switch bits {
        case 0...8:
            return Type.i8
            
        case 9...16:
            return Type.i16
            
        case 17...32:
            return Type.i32
            
        case 33...64:
            return Type.i16
            
        default:
            return Type.invalid
            
        }
    }

    struct Flag: OptionSet {
        var rawValue: UInt64
        init(rawValue: UInt64) { self.rawValue = rawValue }

        static let boolean        = Flag(rawValue: 0b00000001)
        static let integer        = Flag(rawValue: 0b00000010)
        static let unsigned       = Flag(rawValue: 0b00000110)
        static let float          = Flag(rawValue: 0b00001000)
        static let pointer        = Flag(rawValue: 0b00010000)
        static let string         = Flag(rawValue: 0b00100000)
        static let unconstrained  = Flag(rawValue: 0b01000000)

        static let none:         Flag = []
        static let numeric:      Flag = [.integer, .unsigned, .float]
        static let ordered:      Flag = [.numeric, .string, .pointer]
        static let booleanesque: Flag = [.numeric, .boolean]
    }

    var description: String {
        switch kind {
        case .builtin(let name):
            return name

        case .named(let entity):
            return entity.name

        case .alias(let type, let entity):
            return entity.name + " aka " + type.description

        case .pointer(let underlyingType):
            return "*\(underlyingType)"

        case .nullablePointer(let underlyingType):
            return "^\(underlyingType)"

        case .array(let underlyingType, let count):
            return "[\(count)]\(underlyingType)"

        case .proc(let params, let results, let isVariadic):
            // FIXME(vdka): This is wrong.
            // `(, array..[0]any) -> void` should be `(array: [0]any) -> void`
            var str = "("

            if isVariadic {

                var paramStr = ""

                if params.count == 1, let param = params.first {
                    str.append("..")
                    str.append(param.type!.description)
                } else {

                    paramStr.append(
                        params
                            .dropLast()
                            .map({ $0.type!.description })
                            .joined(separator: ", ")
                    )
                    paramStr.append(", ..")
                    paramStr.append(params.last!.type!.description)
                }

                str.append(paramStr)
            } else {
                str.append(params.map({ $0.type!.description }).joined(separator: ", "))
            }
            str.append(")")
            str.append(" -> ")
            str.append(results.map({ $0.description }).joined(separator: ", "))

            return str

        case .struct(let members):
            return "struct { " + members.elements.orderedValues.map({ $0.name + ": " + $0.type!.description }).joined(separator: ", ") + " }"

        case .enum(let cases):
            return "enum { " + cases.elements.orderedValues.map({ $0.name }).joined(separator: ", ") + " }"
            
        case .tuple(let types):
            return "(" + types.map({ $0.description }).joined(separator: ", ") + ")"

        case .type(_):
            return "Metatype"
        }
    }

    var isOrdered: Bool {
        return !flags.union(.ordered).isEmpty
    }

    var isBooleanesque: Bool {
        return isNumeric || isBoolean
    }

    var isNumeric: Bool {
        return isInteger || isFloat || isBoolean
    }

    var isUnconstrained: Bool {
        return flags.contains(.unconstrained)
    }

    var isString: Bool {
        return flags.contains(.string)
    }

    var isBoolean: Bool {
        return flags.contains(.boolean)
    }

    var isInteger: Bool {
        return flags.contains(.integer)
    }

    var isSigned: Bool {
        return isInteger && !isUnsigned
    }

    var isUnsigned: Bool {
        return flags.contains(.unsigned)
    }

    var isFloat: Bool {
        return flags.contains(.float)
    }

    var isPointer: Bool {
        return flags.contains(.pointer)
    }

    var isNullablePointer: Bool {
        switch kind {
        case .named(let entity):
            return entity.type!.isNullablePointer

        case .alias(let type, _):
            return type.isNullablePointer

        case .nullablePointer:
            return true

        default:
            return false
        }
    }

    var isPointeresque: Bool {
        return isPointer || isNullablePointer
    }
    
    var isArray: Bool {
        switch kind {
        case .named(let entity):
            return entity.type!.isArray

        case .alias(let type, _):
            return type.isArray

        case .array:
            return true

        default:
            return false
        }
    }

    var isAlias: Bool {
        if case .alias = kind {
            return true
        }
        return false
    }

    var isStruct: Bool {

        switch kind {
        case .named(let entity):
            return entity.type!.isStruct
            
        case .alias(let type, _):
            return type.isStruct

        case .struct:
            return true

        default:
            return false
        }
    }

    var isProc: Bool {

        switch kind {
        case .named(let entity):
            return entity.type!.isProc
                
        case .alias(let type, _):
            return type.isProc

        case .proc:
            return true

        default:
            return false
        }
    }

    var isTuple: Bool {
        if case .tuple = kind {
            return true
        }
        return false
    }

    var isType: Bool {
        if case .type = kind {
            return true
        }
        return false
    }

    static func ==(lhs: Type, rhs: Type) -> Bool {
        switch (lhs.kind, rhs.kind) {
        case (.builtin, .builtin),
             (.struct, .struct),
             (.alias, .alias),
             (.named, .named):

            // TODO(vdka): Make alias equate possibly?

            return lhs === rhs

        case (.pointer(let lhsUT), .pointer(let rhsUT)):
            return lhsUT == rhsUT

        case (.proc(let lhsParams, let lhsResults, let lhsIsVariadic),
              .proc(let rhsParams, let rhsResults, let rhsIsVariadic)):

            // Whoa.
            return lhsParams.count == rhsParams.count &&
                zip(lhsParams, rhsParams).reduce(true, { $0.0 && $0.1.0.type! == $0.1.1.type! }) &&
                lhsResults.count == rhsResults.count &&
                zip(lhsResults, rhsResults).reduce(true, { $0.0 && $0.1.0 == $0.1.1 }) &&
                lhsIsVariadic == rhsIsVariadic

        case (.type, .type):
            return true

        default:
            return false
        }
    }
}

enum ExactValue {
    case invalid
    case bool(Bool)
    case string(String)
    case integer(Int64)
    case float(Double)
    case type
}

class Entity: PointerHashable {
    var name: String
    var location: SourceLocation
    var kind: Kind
    var flags: Flag = []
    unowned var owningScope: Scope

    // NOTE(vdka): All filled in by the checker

    var type: Type?

    var mangledName: String?

    var childScope: Scope?
    var value: ExactValue?

    var offsetInParent: UInt?
    
    init(name: String, location: SourceLocation = .unknown, kind: Kind, type: Type? = nil, owningScope: Scope) {
        self.name = name
        self.location = location
        self.kind = kind
        self.type = type
        self.owningScope = owningScope
    }

    init(identifier: AstNode, kind: Kind, owningScope: Scope) {
        guard case .ident(let name, let location) = identifier else {
            panic()
        }
        self.name = name
        self.location = location.lowerBound
        self.kind = kind
        self.owningScope = owningScope
    }

    enum Kind {
        case runtime
        case compiletime

        case magic(EntityExtra)

        case importName  //path, name: String, scope: Scope, used: Bool)
        case libraryName // (path, name: String, used: Bool)
        case invalid
    }

    struct Flag: OptionSet {
        var rawValue: UInt8
        init(rawValue: UInt8) { self.rawValue = rawValue }

        static let none = Flag(rawValue: 0b00000000)
        static let used = Flag(rawValue: 0b00000001)
    }

    static var dispose: Entity = {
        return Scope.universal.lookup("_")!
    }()

    var isDispose: Bool {
        return name == "_"
    }

    static func declareBuiltinConstant(name: String, value: ExactValue, scope: Scope) {
        var type: Type
        switch value {
        case .invalid, .type:
            panic()

        case .bool(_):
            type = .unconstrBool

        case .float(_):
            type = .unconstrFloat

        case .integer(_):
            type = .unconstrInteger

        case .string(_):
            type = .unconstrString
        }

        let e = Entity(name: name, location: .unknown, kind: .compiletime, owningScope: scope)
        e.type = type
        e.value = value

        scope.insert(e)
    }

    @available(*, deprecated)
    func child(_ node: AstNode) -> Entity? {

        var members: [Entity]
        switch type?.kind {
        case .struct(let scope)?:
            members = Array(scope.elements.orderedValues)

        case nil:
            return childScope?.lookup(node)

        default:
            return nil
        }

        switch node {
        case .ident(let name, _):
            return members.first(where: { $0.name == name })

        case .exprSelector(let receiver, _, _):
            return self.child(receiver)

        default:
            return nil
        }
    }
}

struct Library {
    var importPath: String
    var fullpath: String
}

class Scope: PointerHashable {
    weak var parent: Scope?
    var imported: [Scope] = []
    var shared: [Scope] = []

    var elements: OrderedDictionary<String, Entity> = [:]
    var isMainFile: Bool = false

    var owningNode: AstNode?
    var owningEntity: Entity?

    var proc: ProcInfo?
    var isProc: Bool { return proc != nil }
    var containingProc: ProcInfo? {
        if let proc = proc {
            return proc
        }

        return parent?.containingProc
    }

    var isStruct: Bool = false
    
    var isSwitch: Bool = false
    var inSwitch: Bool {
        if !isSwitch {
            return parent?.isSwitch ?? false
        }

        return true
    }

    var isLoop: Bool = false
    var inLoop: Bool {
        if !isLoop {
            return parent?.isLoop ?? false
        }

        return true
    }

    /// Only set if scope is file
    var file: ASTFile? = nil
    var isFile: Bool { return file != nil }

    init(parent: Scope?) {
        self.parent = parent
    }
}

extension Scope {

    /// - Returns: Entity replaced by this insertion.
    @discardableResult
    func insert(_ entity: Entity) -> Entity? {
        defer { elements[entity.name] = entity }
        return elements[entity.name]
    }

    func lookup(_ name: String) -> Entity? {

        if let entity = elements[name] {
            return entity
        } else {
            return parent?.lookup(name)
        }
    }

    func lookup(_ node: AstNode) -> Entity? {

        switch node {
        case .ident(let ident, _):
            return lookup(ident)

        case .exprSelector(let receiver, let member, _):
            return lookup(receiver)?.childScope?.lookup(member)

        default:
            return nil
        }
    }
}

class ProcInfo {
    unowned var owningScope: Scope
    var decl: DeclInfo?
    var type: Type
    var node: AstNode // AstNode.litProc

    init(owningScope: Scope, decl: DeclInfo?, type: Type, node: AstNode) {
        self.owningScope = owningScope
        self.decl = decl
        self.type = type
        self.node = node
    }
}

class DeclInfo: PointerHashable {

    unowned var scope: Scope

    /// Each entity represents a reference to the original decl `x := 5; x = x + 8` would have a DeclInfo for `x` with 3 entities
    var entities:  [Entity]
    var typeExpr:   AstNode?
    var initExprs: [AstNode]

    init(scope: Scope, entities: [Entity] = [], typeExpr: AstNode? = nil, initExprs: [AstNode] = []) {
        self.scope = scope
        self.entities = entities
        self.typeExpr = typeExpr
        self.initExprs = initExprs
    }
}

struct DelayedDecl {
    unowned var parent: Scope
    var decl: AstNode
}

struct Checker {
    var parser: Parser
    var currentFile: ASTFile
    var info: Info
    var globalScope: Scope
    var context: Context

    /*
     // ProcedureInfo stores the information needed for checking a procedure
     typedef struct ProcedureInfo {
         AstFile * file;
         Token     token;
         DeclInfo *decl;
         Type *    type; // Type_Procedure
         AstNode * body; // AstNode_BlockStmt
         u32       tags;
     } ProcedureInfo;

    */

    var procs: [ProcInfo] = []

    var delayedImports:  [DelayedDecl] = []
    var delayedLibaries: [DelayedDecl] = []

    /// The entity corresponding to the global 'main' symbol
    var main: Entity?

    /*
	Array(ProcedureInfo)   procs; // NOTE(bill): Procedures to check
	Array(DelayedDecl)     delayed_imports;
	Array(DelayedDecl)     delayed_foreign_libraries;

	Array(Type *)          proc_stack;
	bool                   done_preload;
    */

    init(parser: Parser) {
        self.parser = parser

        currentFile = parser.files.first!
        info = Info()

        globalScope = Scope(parent: .universal)
        context = Context(scope: globalScope)
    }

    struct Info {
        var entities:    [Entity:  DeclInfo] = [:]
        var definitions: [AstNode: Entity]   = [:] // Key: AstNode.ident
        var decls:       [AstNode: DeclInfo] = [:] // Key: AstNode.declValue
        var types:       [AstNode: Type]     = [:] // Key: Any AstNode that can be a type
        var uses:        [AstNode: Entity]   = [:] // Key: AstNode.ident
        var scopes:      [AstNode: Scope]    = [:] // Key: Any AstNode
        var casts:       Set<AstNode>        = [ ] // Key: AstNode.call
    }

    struct Context {
        var scope: Scope
        var inDefer: Bool = false

        init(scope: Scope) {
            self.scope = scope

            inDefer = false
        }
    }
}
















// MARK: Checker functions

extension Checker {

    mutating func checkParsedFiles() {

        declareBuiltins()

        var fileScopes: [String: Scope] = [:]

        for (index, file) in parser.files.enumerated() {

            let scope = Scope(parent: globalScope)
            scope.file = parser.files[index]

            // globalScope.shared.append(scope)

            if index == parser.files.startIndex {
                scope.isMainFile = true
            }

            file.scope = scope
            fileScopes[file.fullpath] = scope
        }

        for file in parser.files {
            let prevContext = context

            setCurrentFile(file)

            // Create entity records for things in file scopes
            collectDecls(file.nodes)

            context = prevContext

            /* If you want to print all entities found in said file
             print("entities found in file \(file.path): ")
             print(Array(file.scope!.elements.keys!))
            */
        }

        importDecls(from: &fileScopes)

        for scope in fileScopes.values {
            checkDecls(in: scope)
        }

        var index = procs.startIndex

        while procs.indices ~= index {
            let pi = procs[index]

            let prevContext = context

            checkProcBody(pi)

            context = prevContext

            index = procs.index(after: index)
        }

        // For now we should require compiler invocation on a single file.
        let mainFile = fileScopes.first(where: { $0.value.isMainFile })!

        main = mainFile.value.lookup("main")
        if main == nil {
            reportError("Undefined entry point 'main'", at: SourceLocation(line: 1, column: 1, file: mainFile.key))
        }
    }
}


// MARK: Check Declarations

extension Checker {

    /// - Precondition: node.isDecl
    @discardableResult
    mutating func collectDecl(_ node: AstNode) -> [Entity] {
        precondition(node.isDecl)

        switch node {
        case .declValue(let isRuntime, let names, let type, let values, _):

            let declInfo = DeclInfo(scope: context.scope)
            declInfo.typeExpr = type

            for (index, name) in names.enumerated() {

                guard name.isIdent else {
                    reportError("A declaration's name must be an identifier", at: name)
                    continue
                }

                let value = values[safe: index].map(unparenExpr)

                var entity: Entity
                if let value = value {
                    entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                    declInfo.initExprs.append(value)
                } else {
                    entity = Entity(identifier: name, kind: isRuntime ? .runtime : .compiletime, owningScope: context.scope)
                }

                declInfo.entities.append(entity)

                addEntity(to: declInfo.scope, entity)

                // TODO(vdka): Check entities are not used in their own intialization.
                info.entities[entity] = declInfo
                info.definitions[name] = entity
            }
            checkArityMatch(node)

            info.decls[node] = declInfo

            return declInfo.entities

        case .declLibrary(let libPathNode, _, let libNameNode, _):

            guard case .litString = libPathNode else {
                panic()
            }

            guard case .ident = libNameNode! else {
                panic()
            }

            let e = Entity(identifier: libNameNode!, kind: .libraryName, owningScope: context.scope)
            addEntity(to: context.scope, e)

            return [e]

            // TODO(vdka): Set any flags for the linking phase to use

        case .declImport:
            if !context.scope.isFile {
                reportError("#import directives are only valid at file scope", at: node)
            }

            let decl = DelayedDecl(parent: context.scope, decl: node)
            delayedImports.append(decl)
            return []

        default:
            // The node doesn't declare anything
            assert(!context.scope.isFile)
            return []
        }
    }

    mutating func collectDecls(_ nodes: [AstNode]) {

        for node in nodes {
            guard node.isDecl else {
                if case .comment = node {
                    continue
                }
                if context.scope.isFile {
                    reportError("Currently only declarations are valid at file scope", at: node)
                }
                continue
            }

            collectDecl(node)
        }
    }

    mutating func importDecls(from fileScopes: inout [String: Scope]) {

        for imp in delayedImports {

            guard case .declImport(let path, let fullpathOpt, let importName, _) = imp.decl else {
                panic()
            }

            guard let fullpath = fullpathOpt else {
                reportError("Failed to import file: \(path)", at: path)
                return
            }

            let parentScope = imp.parent

            assert(parentScope.isFile)

            let scope = fileScopes[fullpath]!

            let previouslyAdded = parentScope.imported.contains(where: { $0 === scope })

            if !previouslyAdded {
                parentScope.imported.append(scope)
            } else {
                reportError("Multiple imports for a single file in current scope", at: imp.decl)
            }

            // import entities into current scope
            if case .ident(".", _)? = importName {

                for entity in scope.elements.orderedValues {
                    addEntity(to: parentScope, entity)
                    parentScope.file!.importedEntities.append(entity)
                }
            } else {
                let (importName, error) = Checker.pathToEntityName(fullpath)
                if error {
                    reportError("File name cannot be automatically assigned an identifier name, you will have to manually specify one.", at: path)
                } else {
                    let e = Entity(name: importName, location: path.startLocation, kind: .importName, owningScope: scope)
                    e.childScope = scope
                    addEntity(to: parentScope, e)
                }
            }
        }
    }

    mutating func checkDecl(of e: Entity) {
        switch e.kind {
        case .libraryName, .importName:
            return

        default:
            guard let decl = info.entities[e] else {
                panic()
            }

            checkDecl(decl)
        }
    }

    mutating func checkDecls(in scope: Scope) {

        let prevContext = context
        context.scope = scope

        for e in scope.elements.orderedValues {
            checkDecl(of: e)
        }

        context = prevContext
    }

    mutating func checkDecl(_ d: DeclInfo) {

        var explicitType: Type?
        if let typeExpr = d.typeExpr {
            explicitType = lookupType(typeExpr)
        }

        if let explicitType = explicitType, explicitType == Type.invalid {
            return
        }

        if d.initExprs.count == 1, d.entities.count > 1, let initExpr = d.initExprs.first, case .exprCall = initExpr {

            let resultType = checkExpr(initExpr)

            if case .tuple(let types) = resultType.kind {
                guard d.entities.count == types.count else {
                    reportError("Arity mismatch got \(d.entities.count) expected \(types.count)", at: initExpr)

                    for e in d.entities {
                        e.type = Type.invalid
                    }
                    return
                }

                for (e, t) in zip(d.entities, types) {
                    e.type = t
                }
            } else {
                reportError("Arity mismatch got \(d.entities.count) expected 1", at: initExpr)
            }

        } else {

            for (i, e) in d.entities.enumerated() {
                let initExpr = d.initExprs[safe: i]
                var rvalueType: Type?
                if let initExpr = initExpr {
                    rvalueType = checkExpr(initExpr, typeHint: explicitType, for: d)
                }

                if let rvalueType = rvalueType, let explicitType = explicitType {

                    // if there is an explicit type ensure we do not conflict with it
                    if !canImplicitlyConvert(rvalueType, to: explicitType) {
                        reportError("Cannot implicitly convert type `\(rvalueType)` to type `\(explicitType)`", at: d.typeExpr!)
                        e.type = Type.invalid
                        continue
                    }

                    let finalType: Type
                    // check if the array is implicitly sized, if so, take the
                    // size of the initialiser
                    if case .array(_, 0) = explicitType.kind {
                        finalType = rvalueType
                    } else {
                        finalType = explicitType
                    }
                    
                    e.type = finalType
                    attemptLiteralConstraint(initExpr!, to: finalType)

                    e.childScope = e.type!.memberScope
                } else if let explicitType = explicitType {

                    e.type = explicitType
                } else if let rvalueType = rvalueType, case .litStruct? = initExpr {

                    e.type = rvalueType

                    let newType = Type.named(e)

                    // Replace nested types
                    for member in rvalueType.memberScope!.elements.orderedValues {
                        if member.type!.underlyingType === Type.placeholder {

                            //
                            // Ensure there is a layer of indirection before the reference to newType
                            guard member.type!.isPointeresque else {
                                // FIXME(vdka): currently Entity does not have reference to it's declaring node. We need that to report it's declaration location
                                reportError("invalid recursive type \(member.type!)", at: initExpr!)
                                member.type = Type.invalid
                                return
                            }

                            var curType = member.type!
                            loop: while true {
                                switch curType.kind {
                                case .pointer(Type.placeholder):
                                    curType.kind = .pointer(underlyingType: newType)
                                    break loop

                                case .nullablePointer(Type.placeholder):
                                    curType.kind = .nullablePointer(underlyingType: newType)
                                    break loop

                                case .pointer(let nextType),
                                     .nullablePointer(let nextType):
                                    curType = nextType

                                default:
                                    panic()
                                }
                            }
                        }
                    }

                } else if let rvalueType = rvalueType, case .litEnum? = initExpr {

                    e.type = rvalueType

                    let newType = Type.named(e)

                    unimplemented()
                } else if let rvalueType = rvalueType, rvalueType.isType {

                    e.type = Type.alias(of: rvalueType, with: e)
                } else if let rvalueType = rvalueType {

                    e.type = rvalueType
                } else {
                    panic() // NOTE(vdka): No explicit type or rvalue
                }
            }
        }
    }
}


// MARK: Actual Checking

extension Checker {

    mutating func checkProcType(_ node: AstNode) -> Type {

        guard case .typeProc(let params, let results, _) = node else {
            panic()
        }

        var isVariadic: Bool = false

        var paramEntities: [Entity] = []
        var returnTypes:   [Type]   = []

        // NOTE(vdka): Ensure that this is the scope used when checking the body of the procedure later
        let scope = Scope(parent: context.scope)
        for param in params {

            let e = Entity(name: "_", location: param.startLocation, kind: .runtime, owningScope: scope)
            switch param {
            case .declValue(_, let names, let type, let values, _):

                assert(names.count == 1, "Parser should explode parameters so each decl has exactly 1 value")
                assert(type != nil)

                guard let ident = names.first, let type = type else {
                    panic()
                }
                if !values.isEmpty {
                    unimplemented("Default procedure argument values")
                }

                assert(ident.isIdent)
                e.name = ident.description
                let paramDecl = DeclInfo(scope: scope, entities: [e], typeExpr: type, initExprs: [])

                if case .ellipsis(let typeNode, _) = type {

                    guard params.last! == param else {
                        reportError("Can only use `..` as final param in list", at: param)
                        return Type.invalid
                    }

                    isVariadic = true
                    e.type = lookupType(typeNode)
                } else {

                    checkDecl(paramDecl)
                }

                paramEntities.append(e)

                info.definitions[ident] = e
                info.entities[e] = paramDecl

            default:
                // TODO(vdka): Validate that the procedure has a foreign body if arg names are omitted.

                let type: Type
                if case .ellipsis(let typeNode, _) = param {

                    guard params.last! == param else {
                        reportError("Can only use `..` as final param in list", at: param)
                        return Type.invalid
                    }

                    isVariadic = true
                    type = lookupType(typeNode)
                } else {

                    type = lookupType(param)
                }

                e.type = type

                paramEntities.append(e)
            }

            info.types[param] = e.type!
        }

        for result in results {
            switch result {
            case .declValue(_, let names, let type, let values, _):
                // NOTE(vdka): In the results, we don't care about the identifier name. Just the type.

                assert(names.count == 1, "Parser should explode results so each decl has exactly 1 value")
                assert(type != nil)

                guard let type = type else {
                    panic()
                }
                if !values.isEmpty {
                    unimplemented("Default procedure argument values")
                }

                let returnType = lookupType(type)
                returnTypes.append(returnType)

            default:
                // If it is not a `declValue` it *must* be a type
                let returnType = lookupType(result)
                returnTypes.append(returnType)
            }
        }

        let type = Type(kind: .proc(params: paramEntities, returns: returnTypes, isVariadic: isVariadic), flags: .none, width: 0, location: nil)

        return type
    }

    mutating func lookupEntity(_ node: AstNode, reportMissing: Bool = true) -> Entity? {

        if case .ident("_", _) = node {
            return Entity.dispose
        }
        guard let entity = context.scope.lookup(node) else {
            if reportMissing {
                reportError("Undeclared entity '\(node)'", at: node)
            }
            return nil
        }

        return entity
    }

    /// Use this when you expect the node you pass in to be a type
    /// - Note: Will warn if the node cannot be used as a type.
    mutating func lookupType(_ node: AstNode) -> Type {
        if let type = info.types[node] {
            return type
        }

        switch node {
        case .ident:

            guard let entity = lookupEntity(node) else {
                return Type.invalid
            }

            switch entity.kind {
            case .compiletime:

                guard let type = entity.type, case .type(let instanceType) = type.kind else {
                    reportError("Entity `\(node)` cannot be used as type", at: node)
                    return Type.invalid
                }

                return instanceType

            default:
                // NOTE(vdka): We could support runtime entities being used as type members.
                reportError("Entity `\(node)` cannot be used as type", at: node)
                return Type.invalid
            }

        case .exprSelector:

            guard let entity = lookupEntity(node) else {
                return Type.invalid
            }

            switch entity.type?.kind {
            case .type(let type)?:
                return type

            default:
                reportError("Entity '\(node)' cannot be used as type", at: node)
                return Type.invalid
            }

        case .typeProc:
            return checkProcType(node)

        case .typePointer(let type, _):
            let underlyingType = lookupType(type)
            return Type.pointer(to: underlyingType)

        case .typeNullablePointer(let type, _):
            let underlyingType = lookupType(type)
            return Type.nullablePointer(to: underlyingType)

        case .typeArray(let count, let type, _):
            let underlyingType = lookupType(type)

            let countValue: UInt
            switch count {
            case .litInteger(let count, _)?:
                countValue = UInt(count)
                
            case .none:
                countValue = 0
                
            default:
                unimplemented("Non literal array sizes")
            }

            return Type.array(of: underlyingType, with: countValue)

        default:
            reportError("'\(node)' cannot be used as a type", at: node)
            return Type.invalid
        }
    }


    // MARK: Check Statements

    mutating func checkStmt(_ node: AstNode) {

        switch node {
        case .comment:
            break

        case .declValue, .declImport, .declLibrary:
            let entities = collectDecl(node)
            for e in entities {
                checkDecl(of: e)
            }

        case _ where node.isExpr:
            checkExpr(node)

        case .stmtBlock(let stmts, _):

            let s = pushScope(for: node)
            defer { popScope() }

            for stmt in stmts {
                checkStmt(stmt)
            }

        case .stmtAssign:
            checkStmtAssign(node)

        case .stmtReturn(let exprs, _):

            guard case .proc(_, let results, _)? = context.scope.containingProc?.type.kind else {
                reportError("'return' is not valid in this scope", at: node)
                return
            }
            for (expr, expectedType) in zip(exprs, results) {
                checkExpr(expr, typeHint: expectedType)
            }

        case .stmtIf(let cond, let body, let elseExpr, _):

            let condType = checkExpr(cond)
            guard canImplicitlyConvert(condType, to: Type.bool) else {
                reportError("Cannot use expression as boolean value", at: cond)
                return
            }

            checkStmt(body)

            if let elseExpr = elseExpr {
                checkStmt(elseExpr)
            }

        case .stmtDefer(let stmt, _):
            checkStmt(stmt)
            // TODO(vdka): Validate that the deferal is unTerminated (defer cannot return)

        case .stmtFor(let initializer, let cond, let step, let body, _):
            
            let bodyScope = pushScope(for: body, isLoop: true)
            defer { popScope() }

            if let initializer = initializer {
                checkStmt(initializer)
            }
            if let cond = cond {
                let type = checkExpr(cond)
                guard canImplicitlyConvert(type, to: Type.bool) else {
                    reportError("Non-bool \(cond) (type \(type)) used as condition", at: cond)
                    return
                }
            }
            if let step = step {
                checkStmt(step)
            }

            guard case .stmtBlock(let stmts, _) = body else {
                panic()
            }
            for stmt in stmts {
                checkStmt(stmt)
            }

        case .stmtSwitch(let subject, let cases, _):
            var subjectType: Type? = nil
            
            if let subject = subject {
                subjectType = checkExpr(subject)
            }
            
            var seenDefaultCase: Bool = false
            
            for caseStmt in cases {
                guard case .stmtCase(let match, let body, _) = caseStmt else {
                    reportError("Expected `case` block in `switch`, got `\(caseStmt)`", at: caseStmt)
                    return
                }
                
                guard !seenDefaultCase else {
                    reportError("Additional `case` blocks cannot be after a `default` block", at: caseStmt)
                    return
                }
                
                if let match = match {
                    let matchType = checkExpr(match)
                    
                    if let subjectType = subjectType {
                        guard canImplicitlyConvert(matchType, to: subjectType) else {
                            reportError("Cannot implicitly convert type `\(matchType)` to `\(subjectType)`", at: match)
                            return
                        }
                    } else /* booleanesque */ {
                        guard canImplicitlyConvert(matchType, to: Type.bool) else {
                            reportError("Non-bool `\(match)` (type `\(matchType)`) used as condition", at: match)
                            return
                        }
                    }
                } else {
                    seenDefaultCase = true
                }

                // NOTE(vdka): We still need to wrap the case in it's own scope in case a variable is declared in the body stmt
                pushScope(for: caseStmt, isSwitch: true)
                checkStmt(body)
                popScope()
            }
            
            guard seenDefaultCase else {
                reportError("A `switch` statement must have a `default` block", at: node)
                return
            }
            
        case .stmtBreak:
            guard context.scope.inLoop || context.scope.inSwitch else {
                reportError("`\(node)` is invalid outside of a loop", at: node)
                return
            }

        case .stmtContinue:
            guard context.scope.inLoop else {
                reportError("`\(node)` is invalid outside of a loop", at: node)
                return
            }

        default:
            unimplemented("Checking for nodes of kind \(node.shortName)")
        }
    }


    mutating func checkStmtAssign(_ node: AstNode) {
        guard case .stmtAssign(let op, let lhs, let rhs, _) = node else {
            panic()
        }

        guard case .equals = op else {
            guard lhs.count == 1 && rhs.count == 1, let lval = lhs.first, let rval = rhs.first else {
                reportError("Complex assignment is limitted to singlular l and r values", at: node)
                return
            }

            let lhsType = checkExpr(lval)
            let rhsType = checkExpr(rval, typeHint: lhsType)

            guard canImplicitlyConvert(rhsType, to: lhsType) else {
                reportError("Cannot use `\(rval)` (type \(rhsType)) as rvalue in assignment to `\(lval)` (type \(lhsType))", at: node)
                return
            }

            return
        }

        if lhs.count > 1, rhs.count == 1, let rval = rhs.first {

            let rType = checkExpr(rval)

            // NOTE(vdka): Only procedures use tuple types.
            if case .tuple(let results) = rType.kind {

                guard lhs.count == results.count else {
                    reportError("Assignment count mismatch: '\(lhs.count) = \(rhs.count)'", at: node)
                    return
                }

                for (lval, result) in zip(lhs, results) {

                    switch lval {
                    case .exprDeref(let expr, _):
                        // FIXME(vdka): This probably won't handle multiple layers of indirection.
                        guard let entity = lookupEntity(expr) else {
                            return
                        }

                        guard entity.type!.isPointer || entity.type!.isNullablePointer else {
                            reportError("FIXME(vdka): Some error", at: expr)
                            return
                        }
                        let underlyingType = entity.type!.underlyingType!

                        // FIXME
                        // FIXME
                        // FIXME

                        guard canImplicitlyConvert(result, to: underlyingType) else {
                            reportError("Cannot use `\(rval)` (type \(result)) as rvalue in assignment to `\(lval)` (type \(entity.type!))", at: rval)
                            return
                        }

                    case .exprUnary(.ampersand, _, _):
                        unimplemented()

                    default:

                        guard let entity = lookupEntity(lval) else {
                            return
                        }

                        guard canImplicitlyConvert(result, to: entity.type!) else {

                            reportError("Cannot use `\(rval)` (type \(result)) as rvalue in assignment to `\(lval)` (type \(entity.type!))", at: rval)
                            return
                        }
                    }

                    // TODO(vdka): There is certainly some more we need to do in here. Figure it out.

                }
                return
            }
        }

        guard lhs.count == rhs.count else {
            reportError("assignment count mismatch: '\(lhs.count) = \(rhs.count)'", at: node)
            return
        }

        // TODO(vdka): Not all of these ops are valid on all types `>>=` `%=`

        for (lval, rval) in zip(lhs, rhs) {
            let rhsType = checkExpr(rval)
            let lhsType = checkExpr(lval, typeHint: rhsType)

            guard canImplicitlyConvert(rhsType, to: lhsType) else {

                reportError("Cannot use `\(rval)` (type \(rhsType)) as rvalue in assignment to `\(lval)` (type \(lhsType))", at: rval)
                return
            }
            if rval.isLit || rval.isNil {
                attemptLiteralConstraint(rval, to: lhsType)
            }
        }
    }


    // MARK: Check Expressions

    @discardableResult
    mutating func checkExpr(_ node: AstNode, typeHint: Type? = nil, for decl: DeclInfo? = nil) -> Type {
        if let type = info.types[node] {
            return type
        }

        if node.isDecl {
            reportError("Unexpected declaration, expected expression", at: node)
            return Type.invalid
        }
        if node.isStmt {
            reportError("Unexpected statement, expected expression", at: node)
            return Type.invalid
        }

        //
        // Remember to set this type whenever the value is not invalid.
        // Do NOT return your valid type directly, you need info.types set for the node.
        //

        var type = Type.invalid

        switch node {
        case .litInteger:
            type = Type.unconstrInteger
            if let typeHint = typeHint, canImplicitlyConvert(type, to: typeHint) {
                performImplicitConversion(on: &type, to: typeHint)
            }

        case .litFloat:
            type = Type.unconstrFloat
            if let typeHint = typeHint, canImplicitlyConvert(type, to: typeHint) {
                performImplicitConversion(on: &type, to: typeHint)
            }

        case .litString:
            type = Type.unconstrString
            if let typeHint = typeHint, canImplicitlyConvert(type, to: typeHint) {
                performImplicitConversion(on: &type, to: typeHint)
            }

        case .litCompound(let typeNode, let elements, _):

            // NOTE(vdka): litCompounds mostly ignore the typeHint thanks to having an explicit type (here typeNode)

            let explicitType = lookupType(typeNode)

            if elements.isEmpty {
                type = explicitType
                break
            }

            if case .array(let underlyingType, let count) = explicitType.kind {

                // TODO(vdka): Check the underlying type is a valid MetaType
                let underlyingInstanceType = underlyingType.instance!

                if elements.count > numericCast(count), count != 0 {
                    reportError("Too many elements in array literal for type `\(explicitType)`", at: elements[numericCast(count)])
                    break
                }

                for element in elements {
                    let elType = checkExpr(element, typeHint: underlyingInstanceType)
                    guard canImplicitlyConvert(elType, to: underlyingInstanceType) else {
                        reportError("Cannot convert `\(elType)` to expected type `\(underlyingType)`", at: element)
                        continue
                    }
                }

                type = explicitType

                break
            }

            if explicitType.isStruct {

                var assigned = Array(repeatElement(false, count: elements.count))
                for (element, member) in zip(elements, explicitType.memberScope!.elements.orderedValues.enumerated()) {

                    assigned[member.offset] = true

                    let targetType = member.element.type!

                    let elType = checkExpr(element, typeHint: targetType)
                    guard canImplicitlyConvert(elType, to: targetType) else {
                        reportError("Cannot convert `\(elType)` to expected type `\(targetType)`", at: element)
                        continue
                    }
                }

                type = explicitType
                break
            }

            // NOTE(vdka): we have handled both Structs and Arrays. There should not be anything else
            panic(node)

        case .litStruct(let members, _):

            let scope = pushScope(for: node, isStruct: true)
            defer { popScope() }

            collectDecls(members)
            checkDecls(in: scope)

            // @hack
            // FIXME(vdka): The ir emitting code should handle the knowledge of values being runtime or not
            //   We may need to mangle non runtime members here though.
            let entities = members.flatMap({ info.decls[$0] }).flatMap({ $0.entities }).filter {
                if case .runtime = $0.kind {
                    return true
                }
                return false
            }

            // FIXME(vdka): Be smarter about this
            // Also allow #packed and whatnot

            var totalWidth: UInt = 0

            for (index, entity) in entities.enumerated() {
                entity.offsetInParent = UInt(index)
                totalWidth += entity.type!.width
            }

            type = Type(kind: .struct(scope), flags: .none, width: totalWidth, location: node.startLocation).type

        case .litEnum(let caseNodes, _):
            
            let scope = pushScope(for: node)
            defer { popScope() }
            
            var cases: [(String, Int)] = []

            var currentValue = 0
            // FIXME(vdka): Currently there is nothing stopping 2 enumeration cases from having the same value.

            for caseNode in caseNodes {

                switch caseNode {
                case .ident(let name, _):
                    cases.append((name, currentValue))
                    
                case .stmtAssign(.equals, let lhs, let rhs, _):
                    guard lhs.count == 1 && rhs.count == 1 else {
                        reportError("Expected enumeration", at: caseNode)
                        continue
                    }
                    
                    guard case .ident(let name, _) = lhs[0] else {
                        reportError("Expected an identifier for enumeration case", at: lhs[0])
                        continue
                    }

                    // FIXME(vdka): We should not be limitted to literals, it should be anything that is compiletime determinable.
                    //  This will also disallow negative values. as they are an AstNode.exprUnary.
                    guard case .litInteger(let value, _) = rhs[0] else {
                        reportError("Expected integer value for enumeration case", at: rhs[0])
                        continue
                    }
                    
                    currentValue = Int(value)
                    cases.append((name, currentValue))
                    
                default:
                    reportError("Excepted enumeration", at: caseNode)
                }
                
                currentValue += 1
            }

            let width = UInt(floor(log2(Double(currentValue - 1))) + 1)

            type = Type(kind: .enum(scope), flags: .none, width: width, location: node.startLocation).type

            for (name, value) in cases {
                let entity = Entity(name: name, kind: .runtime, type: type, owningScope: scope)
                entity.value = ExactValue.integer(Int64(value))
                addEntity(to: scope, entity)
            }
            
        case .ident:
            type = checkExprIdent(node)
            if let typeHint = typeHint, canImplicitlyConvert(type, to: typeHint) {
                performImplicitConversion(on: &type, to: typeHint)
            }

        case .directive("file", let args, _):
            assert(args.isEmpty)
            type = Type.unconstrString
            if let typeHint = typeHint, canImplicitlyConvert(type, to: typeHint) {
                performImplicitConversion(on: &type, to: typeHint)
            }

        case .directive("line", let args, _):
            assert(args.isEmpty)
            type = Type.unconstrInteger
            if let typeHint = typeHint, canImplicitlyConvert(type, to: typeHint) {
                performImplicitConversion(on: &type, to: typeHint)
            }

        case .litProc(let typeNode, _, _):
            type = checkProcType(typeNode)
            queueCheckProc(node, type: type, decl: decl)

        case .exprParen(let node, _):
            type = checkExpr(node, typeHint: typeHint)

        case .exprDeref(let expr, let location):
            let operandType = checkExpr(expr, typeHint: typeHint)

            guard case .pointer(let underlyingType) = operandType.kind else {
                reportError("Cannot dereference non pointer type `\(operandType)`", at: location)
                return Type.invalid
            }
            type = underlyingType

        case .exprUnary:
            type = checkExprUnary(node, typeHint: typeHint)

        case .exprBinary:
            type = checkExprBinary(node, typeHint: typeHint)

        case .exprTernary(let cond, let thenExpr, let elseExpr, _):
            let condType = checkExpr(cond, typeHint: Type.bool)

            guard canImplicitlyConvert(condType, to: Type.bool) else {
                reportError("Cannot use expression as boolean value", at: cond)
                return Type.invalid
            }

            let thenType = checkExpr(thenExpr)
            let elseType = checkExpr(elseExpr)

            guard thenType == elseType else {
                reportError("result values in '? :' expression have mismatching types '\(thenType)' and '\(elseType)'", at: node)
                return Type.invalid
            }
            type = thenType

        case .exprCall(let receiver, let args, _):

            enum CallKind {
                case cast(to: Type)
                case call(params: [Entity], results: [Type], isVariadic: Bool)
                case invalid
            }

            /// If this returns false then we are actually dealing with a cast
            func callKind(for type: Type) -> CallKind {

                switch type.kind {
                case .builtin, .struct, .array, .tuple, .enum:
                    return CallKind.invalid

                case .named(let entity):
                    return callKind(for: entity.type!)
                        
                case .alias(let type, _):
                    return callKind(for: type)

                case .pointer(let underlyingType),
                     .nullablePointer(let underlyingType):
                    return callKind(for: underlyingType)

                case .proc(let params, let results, let isVariadic):
                    return CallKind.call(params: params, results: results, isVariadic: isVariadic)

                case .type(let instanceType):
                    return CallKind.cast(to: instanceType)
                }
            }

            let receiverType = checkExpr(receiver, typeHint: nil)

            if receiverType == Type.invalid {
                return Type.invalid
            }

            switch callKind(for: receiverType) {
            case .call(let params, let resultTypes, let isVariadic):

                // NOTE(vdka): This check allows omitting variadic values.
                if  (isVariadic && args.count - 1 < params.count) &&
                    (!isVariadic && args.count < params.count) {
                    reportError("too few arguments to procedure `\(receiver)`", at: node)
                    break
                } else if args.count > params.count && !isVariadic {
                    reportError("Too many arguments for procedure `\(receiver)`", at: node)
                    break
                }

                for (arg, param) in zip(args, params) {
                    let argType = checkExpr(arg, typeHint: param.type!)
                    if !canImplicitlyConvert(argType, to: param.type!) {
                        reportError("Incompatible type for argument, expected '\(param.type!)' but got '\(argType)'", at: arg)
                        continue
                    }
                }

                if isVariadic && args.count > params.count, let vaargsType = params.last?.type {
                    // NOTE(vdka): At this point we have checked args up to the first variadic arg

                    //
                    // Check trailing varargs all convert to the final param type
                    //

                    let numberOfTrailingArgs = args.count - params.count
                    for arg in args.suffix(numberOfTrailingArgs) {
                        let argType = checkExpr(arg, typeHint: vaargsType.instance!)
                        if !canImplicitlyConvert(argType, to: vaargsType.instance!) {
                            reportError("Incompatible type for argument, expected '\(vaargsType)' but got '\(argType)'", at: arg)
                            continue
                        }
                    }
                }

                if resultTypes.count == 1, let resultType = resultTypes.first {
                    type = resultType
                } else {
                    type = Type.tuple(of: resultTypes)
                }

            case .cast(let targetType):

                guard args.count == 1, let arg = args.first else {
                    if args.count == 0 {
                        reportError("Missing argument for cast to \(receiverType)", at: node)
                    } else { // args.count > 1
                        reportError("Too many arguments for cast to \(receiverType)", at: node)
                    }
                    return Type.invalid
                }

                type = checkExprCast(arg, to: targetType)

                info.casts.insert(node)

            case .invalid:
                reportError("Cannot call expr of type \(type)", at: node)
            }

        case .exprSubscript(let receiver, let value, _):
            let receiverType = checkExpr(receiver, typeHint: nil)

            if receiverType == Type.invalid {
                return Type.invalid
            }
            
            let valueType = checkExpr(value, typeHint: Type.int)
            
            guard canImplicitlyConvert(valueType, to: Type.int) else {
                reportError("Cannot subscript with type \(valueType)", at: value)
                return Type.invalid
            }
            
            switch receiverType.kind {
            case .array(let underlyingType, _),
                 .pointer(let underlyingType),
                 .nullablePointer(let underlyingType):
             
                switch receiverType.kind {
                case .array:
                    type = underlyingType
                    
                case .pointer:
                    type = .pointer(to: underlyingType)
                    
                case .nullablePointer:
                    type = .nullablePointer(to: underlyingType)
                    
                default:
                    break
                }
            
            case .builtin("string"):
                type = .u8

            case .builtin("rawptr"):
                type = .u8
                
            default:
                reportError("Cannot subscript non array type", at: receiver)
                return Type.invalid
            }

        case .exprSelector(let receiver, let member, _):

            if let entity = context.scope.lookup(receiver), case .importName = entity.kind {

                guard let memberEntity = entity.childScope?.lookup(member) else {
                    reportError("Cannot find entity `\(member)` in scope of `\(receiver)`", at: node)
                    return Type.invalid
                }

                type = memberEntity.type!

                break
            }

            let receiverType = checkExpr(receiver)

            guard let memberScope = receiverType.memberScope else {
                reportError("Cannot find entity `\(member)` in scope of `\(receiver)`", at: node)
                return Type.invalid
            }

            guard let memberEntity = memberScope.lookup(member) else {
                reportError("Cannot find entity `\(member)` in scope of `\(receiver)`", at: node)
                return Type.invalid
            }

            type = memberEntity.type!

        case .typePointer(let expr, let location):

            // TODO(vdka): Typehint should be unwrapped. 
            // NOTE(vdka): Last time you saw this you seen that we can't use `underlyingType`
            //    because it may recurse *real* deep if you have `****u8`. 
            //    Instead you want `childType` which for `****u8` would return `***u8`
            let underlyingType = checkExpr(expr, typeHint: typeHint)

            guard case .type(let underlyingInstanceType) = underlyingType.kind else {
                // @errors 
                // FIXME(vdka): check if message is correct here.
                reportError("Unresolved Type `\(expr)`", at: location) 
                return Type.invalid
            }

            type = Type.pointer(to: underlyingInstanceType).type

        case .typeNullablePointer(let expr, let location):

            // TODO(vdka): Typehint should be unwrapped. 
            // NOTE(vdka): Last time you saw this you seen that we can't use `underlyingType`
            //    because it may recurse *real* deep if you have `****u8`. 
            //    Instead you want `childType` which for `****u8` would return `***u8`
            let underlyingType = checkExpr(expr, typeHint: typeHint)

            guard case .type(let underlyingInstanceType) = underlyingType.kind else {
                // @errors
                // FIXME(vdka): check if message is correct here.
                reportError("Unresolved Type `\(expr)`", at: location) 
                return Type.invalid
            }
            type = Type.nullablePointer(to: underlyingInstanceType).type

        case .directive(let string, _, _) where string == "foreign":
            // pass through foreign declarations
            if let typeHint = typeHint {
                type = typeHint
            }

        default:
            // NOTE(vdka): @temp If this is a list node then it's likely that you did:
            // `arr : []u8 = {1, 2, 3}` instead of `arr := []u8{1, 2, 3}`
            panic(node)
        }

        info.types[node] = type
        return type
    }

    struct Branch: OptionSet {
        let rawValue: UInt8

        /// Not a branch
        static let notApplicable = Branch(rawValue: 0b00)
        static let terminated    = Branch(rawValue: 0b01)
        static let unTerminated  = Branch(rawValue: 0b10)
    }

    mutating func checkExprUnary(_ node: AstNode, typeHint: Type?) -> Type {
        guard case .exprUnary(let op, let expr, let location) = node else {
            panic()
        }

        switch op {
        case .plus, .minus: // valid on any numeric type.
            let operandType = checkExpr(expr, typeHint: typeHint)
            guard !Type.Flag.numeric.union(operandType.flags).isEmpty else {
                reportError("Undefined unary operation '\(op)' for \(operandType)", at: location)
                return Type.invalid
            }

            return operandType

        case .bang, .tilde: // valid on any integer type.
            let operandType = checkExpr(expr, typeHint: typeHint)
            guard !Type.Flag.integer.union(operandType.flags).isEmpty else {
                reportError("Undefined unary operation '\(op)' for \(operandType)", at: location)
                return Type.invalid
            }

            return operandType
            
        case .ampersand:
            let operandType = checkExpr(expr, typeHint: typeHint)
            return Type.pointer(to: operandType)

        default:
            reportError("Undefined unary operation '\(op)'", at: location)
            return Type.invalid
        }
    }

    mutating func checkExprBinary(_ node: AstNode, typeHint: Type?) -> Type {
        guard case .exprBinary(let op, let lhs, let rhs, _) = node else {
            panic()
        }

        let lhsType = checkExpr(lhs, typeHint: typeHint)
        let rhsType = checkExpr(rhs, typeHint: typeHint)

        let invalidOpError = "Invalid operation binary operation \(op) between types \(lhsType) and \(rhsType)"

        switch op {
        case .plus where lhsType.isString && rhsType.isString:
            return Type.string

        case .plus,
             .minus,
             .asterix,
             .slash,
             .percent:
            // NOTE(vdka): The first matching case duplicates this so that `string + string` doesn't enter this case body
            guard lhsType.isNumeric && rhsType.isNumeric else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }
            if lhsType == rhsType {
                return lhsType
            } else if canImplicitlyConvert(lhsType, to: rhsType) {
                attemptLiteralConstraint(lhs, to: rhsType)
                return lhsType
            } else if canImplicitlyConvert(rhsType, to: lhsType) {
                attemptLiteralConstraint(rhs, to: lhsType)
                return rhsType
            } else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

            // TODO(vdka): '%' modulo does % work on Float types?

        case .doubleLeftChevron,
             .doubleRightChevron:
            guard lhsType.isInteger && rhsType.isInteger else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }
            if lhsType == rhsType {
                return lhsType
            } else if lhsType.isUnconstrained {
                attemptLiteralConstraint(lhs, to: rhsType)
                return rhsType
            } else if rhsType.isUnconstrained {
                attemptLiteralConstraint(rhs, to: lhsType)
                return lhsType
            } else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

        case .leftChevron,
             .rightChevron,
             .leftChevronEquals,
             .rightChevronEquals,
             .equalsEquals,
             .bangEquals:
            guard lhsType.isOrdered && rhsType.isOrdered else {
                    reportError(invalidOpError, at: node)
                    return Type.invalid
            }

            if lhsType == rhsType {
                // do nothing
            } else if lhsType.isUnconstrained {
                attemptLiteralConstraint(lhs, to: rhsType)
            } else if rhsType.isUnconstrained {
                attemptLiteralConstraint(rhs, to: lhsType)
            }

            return Type.bool

        case .ampersand,
             .carot,
             .pipe:
            guard lhsType.isInteger && rhsType.isInteger else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

            if lhsType == rhsType {
                return lhsType
            }
            if lhsType.width == rhsType.width {
                // FIXME(vdka): once we add more types with different sizes this check is not correct.
                assert(lhsType.isUnsigned != rhsType.isUnsigned)
                reportError("Unable to infer type for result", at: node) // TODO(vdka): Better error
                return Type.invalid
            }
            if rhsType.isUnconstrained {
                attemptLiteralConstraint(rhs, to: lhsType)
            }
            if lhsType.isUnconstrained {
                attemptLiteralConstraint(rhs, to: rhsType)
            }
            if lhsType.width < rhsType.width {
                return rhsType
            }
            if lhsType.width > rhsType.width {
                return lhsType
            }

            panic()

        case .doubleAmpersand,
             .doublePipe:
            guard lhsType.isBooleanesque && rhsType.isBooleanesque else {
                reportError(invalidOpError, at: node)
                return Type.invalid
            }

            return Type.bool

        default:
            reportError(invalidOpError, at: node)
            return Type.invalid
        }
    }

    mutating func checkExprIdent(_ node: AstNode) -> Type {
        guard case .ident(let name, _) = node else {
            panic()
        }

        guard let e = context.scope.lookup(name) else {
            // TODO(vdka): `undef` specifier
            if name == "_" {
                reportError("'_' cannot be used as a value", at: node)
            } else {
                reportError("Undeclared name: '\(name)'", at: node)
            }

            return Type.invalid
        }

        addEntityUse(node, e)

        switch e.kind {
        case .importName:
            reportError("Invalid use of import '\(e.name)'", at: e.location)
            return Type.invalid

        case .libraryName:
            reportError("Invalid use of library '\(e.name)'", at: e.location)
            return Type.invalid

        case .invalid:
            // NOTE(vdka): Should have already warned about this.
            // NOTE(vdka): e.type is likely unset
            return Type.invalid

        default:
            // We should have a type by this point
            return e.type!
        }
    }

    mutating func checkExprCast(_ expr: AstNode, to targetType: Type) -> Type {

        // NOTE(vdka): provide the target type as the hint, just incase we can _hint_ our way there
        let exprType = checkExpr(expr, typeHint: targetType)

        //
        // If we can already implicitly convert then we don't need to check
        // attempt to constrain the exprType to be `type`
        //
        if canImplicitlyConvert(exprType, to: targetType) {
            attemptLiteralConstraint(expr, to: targetType)
            return targetType
        }

        if case .pointer(let exprUnderlyingType) = exprType.kind,
            case .nullablePointer(let targetUnderlyingType) = targetType.kind,
            canImplicitlyConvert(exprUnderlyingType, to: targetUnderlyingType) {

            return targetType
        }

        if case .pointer = exprType.kind, case .pointer(underlyingType: Type.void) = targetType.kind {
            return targetType
        }
        
        //
        // Ensure the two types are of the same size
        //

        if !areTypesRelated(exprType, targetType), targetType.width != exprType.width {
            reportError("Cannot cast between two unrelated types with different sizes", at: expr)
        }

        return targetType
    }

    mutating func checkProcBody(_ pi: ProcInfo) {
        guard case .litProc(_, let body, _) = pi.node else {
            panic()
        }

        assert(info.types[pi.node] != nil)

        guard case .proc(let params, let results, let isVariadic) = pi.type.kind else {
            panic()
        }

        // TODO(vdka): Assert that all params or none of them have names

        guard case .stmtBlock(let stmts, _) = body else {

            let prevContext = context
            defer { context = prevContext }
            context.scope = pi.owningScope

            guard case .directive("foreign", let args, _) = body else {
                reportError("Expected a procedure body to be a block or foreign statement", at: body)
                return
            }

            guard let libNameNode = args[safe: 0], case .ident(let libName, let libLocation) = libNameNode else {
                reportError("Expected the name of the library the symbol will come from", at: args.last?.endLocation ?? body.endLocation)
                return
            }

            guard let entity = context.scope.lookup(libName) else {
                reportError("Undeclared name: '\(libName)'", at: libNameNode)
                return
            }

            guard case .libraryName = entity.kind else {
                reportError("Expected a library identifier", at: libNameNode)
                return
            }

            guard case .litString(let symbol, let symbolLocation)? = args[safe: 1] else {
                reportError("Expected a string literal as the symbol to bind from the library", at: args.first?.startLocation ?? body.endLocation)
                return
            }

            pi.decl?.entities[0].mangledName = symbol

            return
        }

        let s = pushScope(for: body, procInfo: pi)
        defer { popScope() }
        s.parent = pi.owningScope
        s.owningEntity = pi.decl?.entities.first

        // Set the child scopes for each of the declared entities
        pi.decl?.entities.forEach({ $0.childScope = s })

        for entity in params {
            addEntity(to: s, entity)
        }

        // checkStmt(body) would override the scope. We don't want that.
        for stmt in stmts {
            checkStmt(stmt)
        }

        // NOTE(vdka): There must be at least 1 return type or it's an error.
        guard let firstResult = results.first else {
            panic()
        }
        let voidResultTypes = results.count(where: { $0 == Type.void })
        if voidResultTypes > 1 {
            reportError("Multiple returns with a void value is forbidden.", at: pi.node)
        }

        let (terminatingStatements, branches) = terminatingStatments(body)
        guard branches.contains(.terminated) && !branches.contains(.unTerminated) || voidResultTypes == 1 else {
            reportError("Not all procedure body branches return", at: body) // FIXME(vdka): More context on this.
            return
        }

        for returnStmt in terminatingStatements {
            guard case .stmtReturn(let returnedExprs, _) = returnStmt else {
                panic() // implementation error in terminatingStatements
            }

            if returnedExprs.count == 0 && firstResult == Type.void {
                return
            }
            if returnedExprs.count < results.count {
                reportError("Too few return values for procedure. Expected \(results.count), got \(returnedExprs.count)", at: returnStmt)
                break
            } else if returnedExprs.count > results.count {
                reportError("Too many return values for procedure. Expected \(results.count), got \(returnedExprs.count)", at: returnStmt)
                break
            }

            for (returnExpr, resultType) in zip(returnedExprs, results) {
                let returnExprType = checkExpr(returnExpr, typeHint: resultType)
                if !canImplicitlyConvert(returnExprType, to: resultType) {
                    reportError("Incompatible type for return expression. Expected '\(resultType)' but got '\(returnExprType)'", at: returnExpr)
                    continue
                }
            }
        }
    }
}


// MARK: Checker helpers

extension Checker {

    mutating func setCurrentFile(_ file: ASTFile) {
        self.currentFile = file
        self.context.scope = file.scope!
    }

    func mangle(_ entity: Entity) {

        var mangledName = ""

        var owningEntities: [Entity] = []

        var nextScope: Scope? = context.scope

        while let scope = nextScope {
            if let owningEntity = scope.owningEntity {
                owningEntities.append(owningEntity)
            }

            nextScope = scope.parent
        }

        if owningEntities.count == 1,
            let owningEntity = owningEntities.first,
            case .importName = owningEntity.kind {

            //
            // Do not mangle entities from other files
            //

            entity.mangledName = entity.name
            return
        }

        for owner in owningEntities.reversed() {
            mangledName.append(owner.mangledName!)
        }

        // TODO(vdka): If the entity is `#foreign "symbolName"` use the symbolName as the mangled value

        if !mangledName.isEmpty {
            entity.mangledName = mangledName + "." + entity.name
        } else {
            entity.mangledName = entity.name
        }
    }

    @discardableResult
    mutating func addEntity(to scope: Scope, _ entity: Entity) -> Bool {

        if entity.name == "_" {
            return true
        }

        if let conflict = scope.insert(entity) {

            let msg = "Redeclaration of \(entity.name) in this scope\n" +
            "Previous declaration at \(conflict.location)"

            reportError(msg, at: entity.location)
            return false
        }

        mangle(entity)

        return true
    }

    mutating func addEntityUse(_ ident: AstNode, _ entity: Entity) {
        assert(ident.isIdent)
        info.uses[ident] = entity
    }

    @discardableResult
    mutating func checkArityMatch(_ node: AstNode) -> Bool {

        if case .declValue(_, let names, let type, let values, _) = node {
            if values.isEmpty && type == nil {
                reportError("Missing type or initial expression", at: node)
                return false
            } else if names.count < values.count {
                reportError("Arity mismatch, excess expressions on rhs", at: values[names.count])
                return false
            } else if names.count > values.count && values.count != 1 {

                if context.scope.isStruct || (type?.isTypeArray ?? false) {
                    return true
                }

                reportError("Arity mismatch, missing expressions for ident", at: names[values.count])
                return false
            } else if values.count == 1, let value = values.first {
                switch value {
                case .exprCall(let receiver, _, _):
                    guard let procEntity = lookupEntity(receiver, reportMissing: false) else {
                        return true // handle error later
                    }
                    guard case .proc(_, let results, _) = procEntity.type!.kind else {
                        return true // handle error later
                    }

                    return results.count == names.count

                default:
                    return true // handle error later
                }
            }
        }
        
        return true
    }

    func performImplicitConversion(on type: inout Type, to target: Type) {

        guard target != Type.any, target.underlyingType != Type.any else {
            // TODO(vdka): Once we get struct's box this with a pointer to the underlying type and its
            // value if type.width < 8 otherwise put it on the heap and store a pointer
            return
        }

        type = target
    }

    func areTypesRelated(_ a: Type, _ b: Type) -> Bool {
        if canImplicitlyConvert(a, to: b) || canImplicitlyConvert(b, to: a) {
            return true
        } else if a.isNumeric && b.isNumeric {
            return true
        } else if a.isString && b.isString {
            return true
        } else if a.isPointer && b.isPointer {
            return true
        }

        return false
    }

    /// Checks if type `a` can be converted to type `b` implicitly.
    /// True for converting unconstrained types into any of their constrained versions.
    func canImplicitlyConvert(_ type: Type, to target: Type) -> Bool {

        if type == target {
            return true
        }
        if target == Type.any {
            return true
        }

        if type.isUnconstrained {
            if type.isFloat && target.isFloat {
                // `x: f32 = integerValue` | `y: f32 = floatValue`
                return true
            }
            if type.isInteger && target.isFloat {
                // implicitely upcasting an integer into a float is fine.
                return true
            }
            if type.isInteger && target.isInteger {
                // Currently we support converting any integer to any other integer implicitely
                return true
            }
            if type.isBooleanesque && target.isBoolean {
                // Any numeric type can be cast to booleans
                return true
            }
            if type.isBoolean && target.isBoolean {
                return true
            }
            if type.isString && target.isString {
                return true
            }
            if type.isString && target == Type.pointer(to: Type.u8) {
                return true
            }
            if type.isString, case .array(let type, _) = target.kind, type == .u8 {
                return true
            }
            if type.isString && target == Type.pointer(to: Type.void) {
                return true
            }
            if type == Type.unconstrNil && target.isNullablePointer {
                return true
            }
        } else if type.isBooleanesque && target.isBoolean {
            // Numeric types can be converted to booleans through truncation
            return true
        } else if case .pointer(let underlyingType) = type.kind, case .pointer(let underlyingTargetType) = target.kind {
            return canImplicitlyConvert(underlyingType, to: underlyingTargetType)
        } else if case .pointer(let underlyingType) = type.kind, target.isString {
            return canImplicitlyConvert(underlyingType, to: .u8)
        } else if case .array(let underlyingType, _) = type.kind, target.isString {
            return canImplicitlyConvert(underlyingType, to: .u8)
        } else if case .array(let underlyingType, let count) = type.kind,
            case .array(let underlyingTargetType, let targetCount) = target.kind {
            // NOTE(vdka): I am unsure if we should support implicit conversion between 2 arrays with different underlying types
            //  provided their underlying types are implicitely convertable. So I left that out.

            if underlyingTargetType == Type.any {
                return true
            }

            return underlyingType == underlyingTargetType && (count <= targetCount || targetCount == 0)
        } else if type.isType, target == Type.typeInfo {
            return true
        }
        
        return false
    }

    /// - Returns: returns all nodes of kind `stmtReturn` that can be exit points for a scope.
    /// - Note: If not all branches terminate then an empty array is returned.
    func terminatingStatments(_ node: AstNode) -> ([AstNode], Branch) {

        switch node {
        case .stmtReturn:
            return ([node], .terminated)

        case .stmtExpr(let expr):
            return terminatingStatments(expr)

        case .stmtIf(_, let body, let elseExpr, _):
            let bodyTerminators = terminatingStatments(body)
            guard let elseExpr = elseExpr else {
                return (bodyTerminators.0, .unTerminated)
            }

            let elseTerminators = terminatingStatments(elseExpr)

            let allBranchesTerminate = bodyTerminators.1.union(elseTerminators.1)
            return (bodyTerminators.0 + elseTerminators.0, allBranchesTerminate)

        case .stmtBlock(let nodes, _):
            let stmts = nodes.map(terminatingStatments)

            return stmts.reduce(([AstNode](), Branch.notApplicable)) { prior, curr in
                return (prior.0 + curr.0, prior.1.union(curr.1))
            }

        // TODO(vdka): `switch` & `for`
        default:
            return ([], .notApplicable)
        }
    }

    /// Updates the node's type to the target type if `node` matches the lit node for `type`
    mutating func attemptLiteralConstraint(_ node: AstNode, to type: Type) {

        switch node {
        case .litInteger:
            guard type.isInteger else { // We can't constrain a non integer type to an integer
                return
            }
            // NOTE(vdka): If we want to detect wrap in our literals we can do it here.

            info.types[node] = type

        case .litFloat:
            guard type.isFloat else {
                return
            }

            info.types[node] = type

        case .litString:
            guard type.isString else {
                return
            }

            info.types[node] = type

        case .litCompound(_, let elements, _):
            guard case .array(let underlyingType, _) = type.kind else {
                return
            }
            
            elements.forEach {
                attemptLiteralConstraint($0, to: underlyingType)
            }

            info.types[node] = type

        case .ident("nil", _):
            guard type.isNullablePointer else {
                return
            }

            info.types[node] = type
            
        default:
            return
        }
    }
}


// MARK: Even more helpery..

extension Checker {

    @discardableResult
    mutating func pushScope(for node: AstNode, procInfo: ProcInfo? = nil, isLoop: Bool = false, isStruct: Bool = false, isSwitch: Bool = false) -> Scope {
        let scope = Scope(parent: context.scope)
        scope.owningNode = node
        scope.proc = procInfo
        scope.isStruct = isStruct
        scope.isSwitch = isSwitch
        scope.isLoop = isLoop

        info.scopes[node] = scope

        context.scope = scope
        return scope
    }

    mutating func popScope() {
        context.scope = context.scope.parent!
    }

    mutating func queueCheckProc(_ litProcNode: AstNode, type: Type, decl: DeclInfo?) {
        let procInfo = ProcInfo(owningScope: context.scope, decl: decl, type: type, node: litProcNode)
        procs.append(procInfo)
    }
}


// MARK: Universal helpers

extension Checker {

    static func pathToEntityName(_ path: String) -> (String, error: Bool) {
        precondition(!path.isEmpty)

        let filename = String(path.unicodeScalars
            .split(separator: "/").last!
            .split(separator: ".").first!)

        if isValidIdentifier(filename) {
            return (filename, error: false)
        } else {
            return ("_", error: true)
        }
    }

    static func isValidIdentifier(_ str: String) -> Bool {
        guard !str.isEmpty else {
            return false
        }

        if !identChars.contains(str.unicodeScalars.first!) {
            return false
        }

        return str.unicodeScalars.dropFirst()
            .contains(where: { identChars.contains($0) || digits.contains($0) })
    }
}
