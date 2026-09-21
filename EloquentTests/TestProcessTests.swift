import XCTest

@MainActor
final class TestProcessTests: XCTestCase {
    func testDefaultSuiteRunsInTheXCTestProcess() {
        XCTAssertTrue(AppProcess.isRunningTests)
    }
}
