
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
    case `if`
    case `else`
}

enum TrailingDirective: String {
    case linkname
}
