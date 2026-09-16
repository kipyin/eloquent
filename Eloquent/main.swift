import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
ApplicationMenu.install()
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
