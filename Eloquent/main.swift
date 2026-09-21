import AppKit

enum AppProcess {
    // xcodebuild sets these when Eloquent.app is the TEST_HOST. XCTestCase is
    // the fallback if a runner injects the framework without those keys.
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
if AppProcess.isRunningTests {
    app.setActivationPolicy(.regular)
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
