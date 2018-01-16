
enum LoneDirective: String {
    case asm
    case file
    case line
    case location
    case function
}

enum LeadingDirective: String {
    case use
    case `import`
    case library
    case foreign
    case callconv
    case linkname
    case linkprefix
    case test
}

enum TrailingDirective: String {
    case linkname
}

enum TypeDirective: String {
    case inlineTag
    case packed
}
