
# TODO

## Current
- [ ] Cast to different sizes emitting `trunc` or `ext`
- [x] Support nested procedures
- [x] Name mangling
- [ ] Improve name mangling
- [ ] Emit error for _captured_ variables in nested procedures (currently emits bad llvm)
- [ ] Emit error for unused variables (suggesting to use the `_` throw away instead)
- [ ] Syntax for uninitialized variables
- [ ] Switch statements
- [ ] Support multiple returns
- [ ] Support multiple assignment and multiple expressions
- [ ] Require initializer for decls of type pointer
- [ ] Check for usage of pointers after `free` and error

## Big Features
- [ ] Structs
- [ ] Enums
- [ ] Arrays
- [ ] DynamicSizedArrays
- [ ] Slices (maybe can just be a DynamicSizedArray)
- [ ] Unions
- [ ] Procedure Overloading
- [x] Automatic documentation generation (through --emit-docs flag)
- [ ] In Source Code Linker flags (#library)

## Small Features
- [x] Sort out valid variable names mainly the heads for identifiers (`[a-zA-Z_][a-zA-Z0-9_]`)
- [ ] Add unicode characters support. [ref](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html)

## Syntax
- [ ] Allow `(x: int) -> int, error`, Forbid `(x: int) -> (int, error)`
