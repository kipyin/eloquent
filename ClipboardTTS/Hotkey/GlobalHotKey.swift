import AppKit
import Carbon
import os

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let handler: () -> Void

    private static var active: GlobalHotKey?
    private static let log = Logger(subsystem: "com.kipyin.clipboard-tts", category: "hotkey")
    private static let signature: OSType = 0x43545453 // 'CTTS'
    private static let hotKeyIDValue: UInt32 = 1
    private static let escapeKeyCode: UInt32 = 0x35
    private static let optionModifier: UInt32 = 0x0800

    static func optionEscape(handler: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(
            keyCode: escapeKeyCode,
            carbonModifiers: optionModifier,
            handler: handler
        )
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        Self.active = self
        install(keyCode: keyCode, carbonModifiers: carbonModifiers)
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        if Self.active === self {
            Self.active = nil
        }
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
            Self.active?.handler()
        }
        return noErr
    }

    private func install(keyCode: UInt32, carbonModifiers: UInt32) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            clipboardTTSHotKeyHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        guard handlerStatus == noErr else {
            Self.log.error("InstallEventHandler failed: \(handlerStatus, privacy: .public)")
            return
        }

        let identifier = EventHotKeyID(signature: Self.signature, id: Self.hotKeyIDValue)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            identifier,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            Self.log.error("RegisterEventHotKey failed: \(registerStatus, privacy: .public)")
            if let handlerRef {
                RemoveEventHandler(handlerRef)
                self.handlerRef = nil
            }
        }
    }
}

private func clipboardTTSHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    GlobalHotKey.handleCarbonEvent(event)
}
