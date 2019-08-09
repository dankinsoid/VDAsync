import XCTest
@testable import VDAsync

final class VDAsyncTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(VDAsync().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
