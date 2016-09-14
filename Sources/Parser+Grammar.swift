
typealias Action<Input, Output> = (inout Input) -> () throws -> Output

var parserGrammar: Trie<[Lexer.TokenType], Action<Parser, AST.Node>> = {

  func just(node: AST.Node) -> (inout Parser) -> () throws -> AST.Node {

    return { _ in
      return {
        return node
      }
    }
  }

  var parserGrammar: Trie<[Lexer.TokenType], Action<Parser, AST.Node>> = Trie(key: .unknown)

  // parserGrammar.insert(Parser.parseReturnExpression,  forKeyPath: [.returnKeyword])

  // parserGrammar.insert(Parser.parseCall,              forKeyPath: [.identifier, .openParentheses])

  // this will end up being a `call_expr` node. (as it's called in Swift)
  // parserGrammar.insert(just(node: AST.Node(.unknown)), forKeyPath: [.identifier, .openParentheses])

  // `parseStaticDeclaration determines if the following value is a type name, `
  // parserGrammar.insert(Parser.parseStaticDeclaration, forKeyPath: [.identifier, .staticDeclaration])

  return parserGrammar
}()
