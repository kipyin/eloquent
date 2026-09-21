import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
if AppProcess.isRunningTests {
    app.setActivationPolicy(.regular)
}
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
