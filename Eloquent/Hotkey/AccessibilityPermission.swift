import ApplicationServices
import AppKit
import Combine

@MainActor
final class AccessibilityPermission: ObservableObject {
    static let shared = AccessibilityPermission()

    private static let promptedKey = "didPromptAccessibility"

    @Published private(set) var isTrusted = false

    private init() {
        refresh()
    }

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func promptIfNeeded() {
        refresh()
        guard !isTrusted else {
            return
        }
        guard !UserDefaults.standard.bool(forKey: Self.promptedKey) else {
            return
        }
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
        prompt()
    }

    func prompt() {
        refresh()
        guard !isTrusted else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        let hotkey = AppSettings.shared.speakHotkey
        alert.messageText = "Allow Eloquent to use \(hotkey.words)"
        alert.informativeText = """
        Eloquent speaks the clipboard from any app when you press \(hotkey.displayLabel). macOS requires Accessibility permission for that global hotkey.

        1. Click Grant Accessibility.
        2. In System Settings → Privacy & Security → Accessibility, enable Eloquent (or Xcode if you launched from Xcode).
        3. Quit Eloquent from the menu bar and reopen it.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Accessibility")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        requestTrustAndOpenSettings()
    }

    func requestTrustAndOpenSettings() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSystemSettings()
        refresh()
    }

    func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
