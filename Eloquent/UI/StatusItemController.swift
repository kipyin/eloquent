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
        // Square length keeps an icon-only item from collapsing in a packed menu bar.
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.autosaveName = "EloquentStatusItem"
        statusItem.isVisible = true
        statusItem.button?.toolTip = "Eloquent"
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

        AppSettings.shared.$speakHotkey
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
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = templateSymbol(named: symbolName(for: speech.state))
            ?? templateSymbol(named: "speaker.fill")
            ?? Self.fallbackSpeakerImage
    }

    private func symbolName(for state: SpeechController.State) -> String {
        switch state {
        case .playing:
            return "speaker.wave.3.fill"
        case .paused:
            return "speaker.wave.2"
        case .loading:
            return "speaker.wave.1.fill"
        case .failed:
            return "speaker.slash.fill"
        case .idle:
            return "speaker.fill"
        }
    }

    private func templateSymbol(named name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: "Eloquent")?
            .withSymbolConfiguration(configuration)
        else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    private static let fallbackSpeakerImage: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let cone = NSBezierPath()
            cone.move(to: NSPoint(x: rect.minX + 2.5, y: rect.midY - 2.5))
            cone.line(to: NSPoint(x: rect.minX + 7, y: rect.midY - 2.5))
            cone.line(to: NSPoint(x: rect.minX + 11.5, y: rect.midY - 6.5))
            cone.line(to: NSPoint(x: rect.minX + 11.5, y: rect.midY + 6.5))
            cone.line(to: NSPoint(x: rect.minX + 7, y: rect.midY + 2.5))
            cone.line(to: NSPoint(x: rect.minX + 2.5, y: rect.midY + 2.5))
            cone.close()
            cone.fill()
            NSColor.black.setStroke()
            let wave = NSBezierPath()
            wave.appendArc(
                withCenter: NSPoint(x: rect.minX + 11, y: rect.midY),
                radius: 4.5,
                startAngle: -48,
                endAngle: 48
            )
            wave.lineWidth = 1.6
            wave.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()

    private func rebuildMenu() {
        let menu = NSMenu()

        let hotkey = AppSettings.shared.speakHotkey
        let speakItem = NSMenuItem(
            title: hotkey.menuTitle,
            action: #selector(speakMenuItem),
            keyEquivalent: hotkey.menuKeyEquivalent
        )
        speakItem.keyEquivalentModifierMask = hotkey.menuModifierFlags
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
