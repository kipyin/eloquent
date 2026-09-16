import AppKit

private func breadcrumb(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) main: \(message)\n"
    let path = "/tmp/eloquent-launch.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

breadcrumb("starting")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
breadcrumb("delegate set, calling NSApplicationMain")
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
