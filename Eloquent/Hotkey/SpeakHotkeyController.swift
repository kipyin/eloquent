import Combine
import Foundation

@MainActor
final class SpeakHotkeyController: ObservableObject {
    static let shared = SpeakHotkeyController()

    @Published private(set) var lastError: String?
    @Published private(set) var isRecording = false

    private static let conflictMessage = "That shortcut is already used by another app."

    private var hotKey: GlobalHotKey?

    private init() {}

    func start(handler: @escaping () -> Void) {
        hotKey = GlobalHotKey(binding: AppSettings.shared.speakHotkey, handler: handler)
    }

    @discardableResult
    func apply(_ binding: HotkeyBinding) -> Bool {
        if let rejection = binding.rejection {
            lastError = rejection.message
            return false
        }
        guard let hotKey else {
            lastError = "The hotkey is not installed."
            return false
        }
        guard hotKey.rebind(binding) else {
            lastError = Self.conflictMessage
            return false
        }
        AppSettings.shared.speakHotkey = binding
        lastError = nil
        return true
    }

    func reinstallAfterReset() {
        cancelRecording()
        if apply(.optionEscape) {
            return
        }
        if let installed = hotKey?.binding {
            AppSettings.shared.speakHotkey = installed
        }
    }

    func beginRecording() {
        isRecording = true
        lastError = nil
        hotKey?.setPaused(true)
    }

    func cancelRecording() {
        isRecording = false
        hotKey?.setPaused(false)
    }

    func finishRecording(with binding: HotkeyBinding) {
        isRecording = false
        apply(binding)
        hotKey?.setPaused(false)
    }

    func stop() {
        hotKey = nil
    }
}
