import AppKit
import Carbon
import os

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var localMonitor: Any?
    private let handler: () -> Void
    private(set) var binding: HotkeyBinding
    private(set) var isPaused = false

    private static var active: GlobalHotKey?
    private static let log = Logger(subsystem: "com.kipyin.eloquent", category: "hotkey")
    private static let signature: OSType = 0x454C4F51 // 'ELOQ'
    private static let hotKeyIDValue: UInt32 = 1

    init(binding: HotkeyBinding, handler: @escaping () -> Void) {
        self.binding = binding
        self.handler = handler
        Self.active = self
        installHandler()
        if !register(binding) {
            Self.log.error("RegisterEventHotKey failed for \(binding.words, privacy: .public)")
        }
        installLocalMonitor()
    }

    deinit {
        unregisterHotKey()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if Self.active === self {
            Self.active = nil
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            unregisterHotKey()
            return
        }
        if hotKeyRef == nil {
            _ = register(binding)
        }
    }

    func rebind(_ binding: HotkeyBinding) -> Bool {
        if binding == self.binding, hotKeyRef != nil {
            return true
        }
        let previous = self.binding
        let hadPrevious = hotKeyRef != nil
        unregisterHotKey()
        if register(binding) {
            self.binding = binding
            return true
        }
        if hadPrevious {
            _ = register(previous)
        }
        return false
    }

    fileprivate static func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return OSStatus(eventNotHandledErr)
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else {
            return OSStatus(eventNotHandledErr)
        }
        guard hotKeyID.signature == signature, hotKeyID.id == hotKeyIDValue else {
            return OSStatus(eventNotHandledErr)
        }

        DispatchQueue.main.async {
            Self.active?.fire()
        }
        return noErr
    }

    private func fire() {
        guard !isPaused else {
            return
        }
        handler()
    }

    private func installLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let active = Self.active, !active.isPaused, !event.isARepeat, active.binding.matches(event) else {
                return event
            }
            // Carbon already delivers this press. Swallow so a focused Settings
            // field does not also type the shortcut. Fire here only when
            // RegisterEventHotKey is not installed, so Settings-key still speaks.
            if active.hotKeyRef == nil {
                DispatchQueue.main.async {
                    Self.active?.fire()
                }
            }
            return nil
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            eloquentHotKeyHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        if handlerStatus != noErr {
            Self.log.error("InstallEventHandler failed: \(handlerStatus, privacy: .public)")
        }
    }

    private func register(_ binding: HotkeyBinding) -> Bool {
        let identifier = EventHotKeyID(signature: Self.signature, id: Self.hotKeyIDValue)
        let registerStatus = RegisterEventHotKey(
            binding.carbonKeyCode,
            binding.carbonModifiers,
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            hotKeyRef = nil
            Self.log.error("RegisterEventHotKey failed: \(registerStatus, privacy: .public)")
            return false
        }
        return true
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

private func eloquentHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    GlobalHotKey.handleCarbonEvent(event)
}
