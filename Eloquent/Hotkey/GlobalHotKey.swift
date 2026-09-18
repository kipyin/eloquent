import AppKit
import Carbon
import os

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastFire: TimeInterval = 0
    private let handler: () -> Void

    private static var active: GlobalHotKey?
    private static let log = Logger(subsystem: "com.kipyin.eloquent", category: "hotkey")
    private static let signature: OSType = 0x454C4F51 // 'ELOQ'
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
        installEventMonitors()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
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

        // Stamp event time before the queue hop so both deliveries of one
        // keypress coalesce no matter how long the handler blocks the queue.
        let timestamp = ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.async {
            Self.active?.fire(at: timestamp)
        }
        return noErr
    }

    fileprivate static func isOptionEscape(_ event: NSEvent) -> Bool {
        let significant = event.modifierFlags.intersection([.command, .shift, .control, .option])
        return event.keyCode == 53 && significant == .option
    }

    private func fire(at timestamp: TimeInterval) {
        if timestamp - lastFire < 0.2 {
            return
        }
        lastFire = timestamp
        handler()
    }

    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard Self.isOptionEscape(event) else {
                return
            }
            let timestamp = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async {
                Self.active?.fire(at: timestamp)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard Self.isOptionEscape(event) else {
                return event
            }
            let timestamp = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async {
                Self.active?.fire(at: timestamp)
            }
            return nil
        }
    }

    private func install(keyCode: UInt32, carbonModifiers: UInt32) {
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

private func eloquentHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    GlobalHotKey.handleCarbonEvent(event)
}
