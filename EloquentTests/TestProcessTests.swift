import XCTest

@MainActor
final class TestProcessTests: XCTestCase {
    func testDefaultSuiteRunsInTheXCTestProcess() {
        XCTAssertTrue(AppProcess.isRunningTests)
    }

    func testKeychainLoadDoesNotPresentAuthenticationUI() {
        _ = KeychainStore().loadAPIKey()
    }
}
