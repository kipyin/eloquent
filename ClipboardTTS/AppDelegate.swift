import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let speech = SpeechController()
    private let settingsWindow = SettingsWindowController()
    private var statusItem: StatusItemController?
    private var playbackPanel: PlaybackPanelController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        speech.stop()
        hotKey = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
