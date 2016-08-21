import XCTest
@testable import Kai

class KaiTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(Kai().text, "Hello, World!")
    }


    static var allTests : [(String, (KaiTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
