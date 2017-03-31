
# TODO

## Current
- [ ] Cast to different sizes emitting `trunc` or `ext`
- [ ] Support nested procedures
- [ ] Name mangling

## Big Features
- [ ] Structs
- [ ] Enums
- [ ] Arrays
- [ ] DynamicSizedArrays
- [ ] Slices (maybe can just be a DynamicSizedArray)
- [ ] Unions
- [ ] Procedure Overloading
- [ ] Automatic documentation generation (through --docs flag)
- [ ] In Source Code Linker flags (#library)

## Small Features
- [x] Sort out valid variable names mainly the heads for identifiers (`[a-zA-Z_][a-zA-Z0-9_]`)
- [ ] Add unicode characters support. [ref](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html)

## Syntax
- [ ] Allow `(x: int) -> int, error`, Forbid `(x: int) -> (int, error)`
