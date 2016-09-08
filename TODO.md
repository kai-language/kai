
# TODO

## Where I left off

- Parser
  - Parse in scopes (procedure bodies?)
- IRBuilder
  - Implement serialization of the bare minimum for building IR for the main return 5 function.

## Yet to Come but obvious needs
- [ ] Type checker
  - Idea being that you have an untyped AST and you pass it through the type checker getting back a fully typed AST

## Big Features
- [ ] Unions

## Small Features
- [ ] Sort out valid variable names mainly the heads for identifiers ([a-zA-Z_][a-zA-Z0-9_]) Then unicode characters

## Syntax
- [ ] Review Forcing the user to wrap multiple input and output types for procedures in parenthesis
