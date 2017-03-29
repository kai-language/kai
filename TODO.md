
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

## Small Features
- [x] Sort out valid variable names mainly the heads for identifiers (`[a-zA-Z_][a-zA-Z0-9_]`)
- [ ] Add unicode characters support. [ref](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html)

## Syntax
- [ ] Review Forcing the user to wrap multiple output types for procedures in parenthesis
    - `(x: int) -> (int, error)` vs `(x: int) -> int, error`
