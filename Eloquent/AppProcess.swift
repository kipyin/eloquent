import Foundation

enum AppProcess {
    // xcodebuild sets these when XCTest is running. XCTestCase is the fallback
    // if a runner injects the framework without those keys.
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        if environment["XCTestSessionIdentifier"] != nil {
            return true
        }
        if environment["XCInjectBundleInto"] != nil {
            return true
        }
        return NSClassFromString("XCTestCase") != nil
    }
}
