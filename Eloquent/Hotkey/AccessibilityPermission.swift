import ApplicationServices
import AppKit
import Combine

@MainActor
final class AccessibilityPermission: ObservableObject {
    static let shared = AccessibilityPermission()

    /// Shown on every untrusted grant surface: System Settings can keep an
    /// older ad-hoc build's entry enabled while this copy stays untrusted.
    static let adHocRebuildNote = "Rebuilt Eloquent unsigned or ad-hoc? macOS may show an older Eloquent entry as enabled while this copy stays untrusted — remove that entry, then grant again."

    private static let promptedKey = "didPromptAccessibility"

    @Published private(set) var isTrusted = false

    private init() {
        refresh()
    }

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    private func refreshAndAllowsPrompt() -> Bool {
        refresh()
        guard !AppProcess.isRunningTests else {
            return false
        }
        guard !isTrusted else {
            return false
        }
        return true
    }

    func promptIfNeeded() {
        guard refreshAndAllowsPrompt() else {
            return
        }
        guard !UserDefaults.standard.bool(forKey: Self.promptedKey) else {
            return
        }
        UserDefaults.standard.set(true, forKey: Self.promptedKey)
        prompt()
    }

    func prompt() {
        guard refreshAndAllowsPrompt() else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        let hotkey = AppSettings.shared.speakHotkey
        alert.messageText = "Allow Eloquent to use \(hotkey.words)"
        alert.informativeText = """
        macOS does not trust Eloquent yet, so \(hotkey.words) speaks only the clipboard instead of the selection. Eloquent needs Accessibility permission so the global hotkey can read the selected text in every app.

        1. Click Grant Accessibility — System Settings opens at Privacy & Security → Accessibility.
        2. Enable Eloquent (or Xcode if you launched from Xcode).
        3. Quit Eloquent from the menu bar and reopen it.

        \(Self.adHocRebuildNote)
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
