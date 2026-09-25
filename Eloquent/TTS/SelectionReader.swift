import ApplicationServices
import Foundation

struct SelectionReader: SelectionReading {
    // Bound the IPC so a hung frontmost app fails into the clipboard fallback
    // instead of freezing the hotkey path.
    private static let messagingTimeout: Float = 1

    func selectedText() -> String? {
        guard AXIsProcessTrusted() else {
            return nil
        }
        let systemWide = AXUIElementCreateSystemWide()
        _ = AXUIElementSetMessagingTimeout(systemWide, Self.messagingTimeout)
        guard let focusedApp: AXUIElement = copyAttribute(kAXFocusedApplicationAttribute, of: systemWide),
              let focusedElement: AXUIElement = copyAttribute(kAXFocusedUIElementAttribute, of: focusedApp),
              let raw: String = copyAttribute(kAXSelectedTextAttribute, of: focusedElement) else {
            return nil
        }
        return raw.nonEmptyTrimmed
    }

    private func copyAttribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }
}
