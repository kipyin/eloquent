import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var speech: SpeechController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: StatusItemController?
    private var playbackPanel: PlaybackPanelController?
    private static let log = Logger(subsystem: "com.kipyin.eloquent", category: "app")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // TEST_HOST launches this app. Skip menu-bar chrome, Keychain, and
        // Accessibility prompts so XCTest is not blocked by a modal, and
        // become a regular app so an LSUIElement host does not wait forever.
        if AppProcess.isRunningTests {
            NSApp.setActivationPolicy(.regular)
            return
        }

        ApplicationMenu.install()
        NSApp.setActivationPolicy(.accessory)

        speech = SpeechController()
        settingsWindow = SettingsWindowController(speech: speech)
        playbackPanel = PlaybackPanelController(speech: speech)
        statusItem = StatusItemController(
            speech: speech,
            onSpeak: { [weak self] in
                self?.speech.speak()
            },
            onSettings: { [weak self] in
                self?.settingsWindow.show()
            }
        )
        SpeakHotkeyController.shared.start { [weak self] in
            self?.speech.speak()
        }

        Self.log.info("Eloquent launched; status item ready")

        DispatchQueue.main.async {
            AccessibilityPermission.shared.promptIfNeeded()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !AppProcess.isRunningTests else {
            return
        }
        AccessibilityPermission.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        speech?.stop()
        SpeakHotkeyController.shared.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

}
