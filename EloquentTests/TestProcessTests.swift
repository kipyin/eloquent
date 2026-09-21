import XCTest

@MainActor
final class TestProcessTests: XCTestCase {
    func testDefaultSuiteRunsInTheXCTestProcess() {
        XCTAssertTrue(AppProcess.isRunningTests)
    }

    func testAccessibilityPromptReturnsWithoutAModal() {
        AccessibilityPermission.shared.promptIfNeeded()
        AccessibilityPermission.shared.prompt()
    }

    func testKeychainLoadDoesNotPresentAuthenticationUI() {
        _ = KeychainStore().loadAPIKey()
    }
}
