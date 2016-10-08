
# TODO

## Current
- [ ] fix Directive.foreignLLVM by making it a single case that contains the foreign source. (Symbol.Source)-esque

## Big Features
- [ ] Unions
- [ ] Go style interfaces?
  - @ compile time a so called _`interface`_ could be declared that basically would just define a set of field's available.
  - Because these can only be created @ compile time and we know what field's everything have we can use interface'd type's to allow more flexibility about what could be passed into functions.
  - `ErrorType :: interface { message: String }`
  - Go seems to retain the ability to do this type @ runtime because it's how you handle JSON:
```go
import "json" .
var json interface { }
error := Unmarshal(bytes, &json)
/*
bool, for JSON booleans
float64, for JSON numbers
string, for JSON strings
[]interface{}, for JSON arrays
map[string]interface{}, for JSON objects
nil for JSON null
*/
```

## Small Features
- [x] Sort out valid variable names mainly the heads for identifiers (`[a-zA-Z_][a-zA-Z0-9_]`)
- [ ] Add unicode characters support. [ref](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html)

## Syntax
- [ ] Review Forcing the user to wrap multiple input and output types for procedures in parenthesis

## Compilation steps for executables

1. Begin by constructing an untyped AST for `main.kai` (by default)
2. During AST construction whenever an `import "file.kai"` found we mark that file as needing to be processed. (this may begin on another thread)
3. Begin filling in types on the AST of the `main.kai` file.
  - Should we encounter any node's that cannot have their type's resolved _then_ we wait for the `import`s to be resolved then check if they contain any reachable symbols that can be used to resolve the current Node's type.
  - This solution means the imported files do not need to be fully type checked.
