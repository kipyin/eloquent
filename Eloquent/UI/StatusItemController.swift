import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject {
    private let speech: SpeechController
    private let onSpeak: () -> Void
    private let onSettings: () -> Void
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(speech: SpeechController, onSpeak: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.speech = speech
        self.onSpeak = onSpeak
        self.onSettings = onSettings
        // Fixed square length + title fallback so the item stays visible when the
        // menu bar is crowded or the SF Symbol fails to resolve.
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.autosaveName = "EloquentStatusItem"
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.toolTip = "Eloquent"
            button.title = "Elo"
            button.imagePosition = .imageLeading
        }
        configureButton()
        rebuildMenu()

        speech.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.configureButton()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        AccessibilityPermission.shared.$isTrusted
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }
        let symbolName: String
        switch speech.state {
        case .playing:
            symbolName = "speaker.wave.2.fill"
        case .paused:
            symbolName = "speaker.wave.2"
        case .loading:
            symbolName = "ellipsis.circle"
        case .failed:
            symbolName = "speaker.slash"
        case .idle:
            symbolName = "speaker.wave.2.fill"
        }
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Eloquent") {
            image.isTemplate = true
            button.image = image
            button.title = "Elo"
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
            button.title = "Elo"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let speakItem = NSMenuItem(
            title: "Speak Selection or Clipboard",
            action: #selector(speakMenuItem),
            keyEquivalent: "\u{1b}"
        )
        speakItem.keyEquivalentModifierMask = [.option]
        speakItem.target = self
        menu.addItem(speakItem)

        menu.addItem(.separator())

        let statusItem = NSMenuItem(
            title: statusTitle(),
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if !AccessibilityPermission.shared.isTrusted {
            menu.addItem(.separator())
            let grantItem = NSMenuItem(
                title: "Grant Accessibility…",
                action: #selector(grantAccessibilityMenuItem),
                keyEquivalent: ""
            )
            grantItem.target = self
            menu.addItem(grantItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(settingsMenuItem),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Eloquent",
            action: #selector(quitMenuItem),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    private func statusTitle() -> String {
        switch speech.state {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading \(speech.progressLabel)"
        case .playing:
            return "Speaking \(speech.progressLabel)"
        case .paused:
            return "Paused \(speech.progressLabel)"
        case .failed(let message):
            return message
        }
    }

    @objc
    func speakMenuItem() {
        onSpeak()
    }

    @objc
    func settingsMenuItem() {
        onSettings()
    }

    @objc
    func grantAccessibilityMenuItem() {
        AccessibilityPermission.shared.prompt()
    }

    @objc
    func quitMenuItem() {
        NSApp.terminate(nil)
    }
}
