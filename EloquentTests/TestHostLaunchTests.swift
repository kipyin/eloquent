import XCTest
@testable import Eloquent

@MainActor
final class TestHostLaunchTests: XCTestCase {
    func testDefaultSuiteRunsInsideTheXCTestHost() {
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
