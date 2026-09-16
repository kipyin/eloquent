import AppKit
import ApplicationServices
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var speech: SpeechController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: StatusItemController?
    private var playbackPanel: PlaybackPanelController?
    private var hotKey: GlobalHotKey?

    private static let log = Logger(subsystem: "com.kipyin.eloquent", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.writeLaunchBreadcrumb("didFinishLaunching begin")
        NSApp.setActivationPolicy(.accessory)

        speech = SpeechController()
        settingsWindow = SettingsWindowController()
        playbackPanel = PlaybackPanelController(speech: speech)
        statusItem = StatusItemController(
            speech: speech,
            onSpeak: { [weak self] in
                self?.speech.speakClipboard()
            },
            onSettings: { [weak self] in
                self?.settingsWindow.show()
            }
        )
        hotKey = GlobalHotKey.optionEscape { [weak self] in
            self?.speech.speakClipboard()
        }

        Self.writeLaunchBreadcrumb(
            "statusItem created=\(statusItem != nil) trusted=\(AXIsProcessTrusted())"
        )
        Self.log.info("Eloquent launched; status item ready")

        DispatchQueue.main.async {
            AccessibilityPermission.shared.promptIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AccessibilityPermission.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        speech?.stop()
        hotKey = nil
        Self.writeLaunchBreadcrumb("willTerminate")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private static func writeLaunchBreadcrumb(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/eloquent-launch.log")
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
