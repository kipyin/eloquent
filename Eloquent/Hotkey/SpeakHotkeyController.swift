import AppKit
import Combine
import Foundation

@MainActor
final class SpeakHotkeyController: ObservableObject {
    static let shared = SpeakHotkeyController()

    @Published private(set) var lastError: String?
    @Published private(set) var isRecording = false

    private static let conflictMessage = "That shortcut is already used by another app."

    private var hotKey: GlobalHotKey?
    private var monitor: Any?

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
        installMonitor()
    }

    func cancelRecording() {
        removeMonitor()
        isRecording = false
        hotKey?.setPaused(false)
    }

    private var isAwaitingKeyRelease: Bool {
        !isRecording && (hotKey?.isPaused == true)
    }

    func finishRecording(with binding: HotkeyBinding) {
        isRecording = false
        apply(binding)
    }

    func resumeAfterRecording() {
        removeMonitor()
        hotKey?.setPaused(false)
    }

    func stop() {
        cancelRecording()
        hotKey = nil
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleCaptureEvent(event) ?? event
        }
    }

    private func handleCaptureEvent(_ event: NSEvent) -> NSEvent? {
        if isRecording {
            guard event.type == .keyDown else {
                return nil
            }
            if event.isARepeat {
                return nil
            }
            let modifiers = HotkeyModifiers(eventFlags: event.modifierFlags)
            if event.keyCode == HotkeyBinding.escapeKeyCode, modifiers.isEmpty {
                cancelRecording()
                return nil
            }
            finishRecording(with: HotkeyBinding(event: event))
            return nil
        }
        if isAwaitingKeyRelease {
            if event.type == .keyDown {
                return nil
            }
            if event.type == .keyUp || HotkeyModifiers(eventFlags: event.modifierFlags).isEmpty {
                resumeAfterRecording()
            }
            return nil
        }
        return event
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
