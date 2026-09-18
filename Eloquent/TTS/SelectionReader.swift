import ApplicationServices
import Foundation

// Reads the frontmost app's focused selected text through Accessibility.
protocol SelectionReading: Sendable {
    func selectedText() -> String?
}

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
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func copyAttribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }
}
