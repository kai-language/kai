
import XCTest
@testable import kai

class LexerTests: XCTestCase {

  func testSimpleList() {

    let bytes = Array("name := 5".utf8)

    let lexer = Lexer(bytes)

    let tokens = lexer.tokenize()
  }
}
