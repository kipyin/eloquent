import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var speech: SpeechController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: StatusItemController?
    private var playbackPanel: PlaybackPanelController?
    private var hotKey: GlobalHotKey?

    private static let log = Logger(subsystem: "com.kipyin.eloquent", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
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
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

}
