import Foundation
import os

enum AppProcess {
    static let displayName = "Eloquent"
    static let bundleIdentifier = "com.kipyin.eloquent"

    static func logger(category: String) -> Logger {
        Logger(subsystem: bundleIdentifier, category: category)
    }

    // xcodebuild sets these when XCTest is running. XCTestCase is the fallback
    // if a runner injects the framework without those keys.
    private static let testEnvironmentKeys = [
        "XCTestConfigurationFilePath",
        "XCTestSessionIdentifier",
        "XCInjectBundleInto",
    ]

    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if testEnvironmentKeys.contains(where: { environment[$0] != nil }) {
            return true
        }
        return NSClassFromString("XCTestCase") != nil
    }
}
