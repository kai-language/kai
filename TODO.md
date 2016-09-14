
# TODO

## Where I left off

## Yet to Come but obvious needs
- [ ] Lex only as we need
  - by making a buffered scanner where calls to peek will call the mutating `next() -> Element?` and store the input in a Queue. This allows _read as you need_ behavior and still permits arbitrary lookahead
- [ ] Type checker
  - Idea being that you have an untyped AST and you pass it through the type checker getting back a fully typed AST

## Big Features
- [ ] Unions

## Small Features
- [x] Sort out valid variable names mainly the heads for identifiers (`[a-zA-Z_][a-zA-Z0-9_]`)
- [ ] Add unicode characters support. [ref](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html)

## Syntax
- [ ] Review Forcing the user to wrap multiple input and output types for procedures in parenthesis

## Thoughts

- [ ] In order to have a decent incremental compilation mechanism we should serialize one of the AST's to disk.

# Lexer

- [ ] Tests
  - [ ] `parseNumber`

## Compilation steps for executables

1. Begin by constructing an untyped AST for `main.kai` (by default)
2. During AST construction whenever an `import "file.kai"` found we mark that file as needing to be processed. (this may begin on another thread)
3. Begin filling in types on the AST of the `main.kai` file.
  - Should we encounter any node's that cannot have their type's resolved _then_ we wait for the `import`s to be resolved then check if they contain any reachable symbols that can be used to resolve the current Node's type.
  - This solution means the imported files do not need to be fully type checked.
