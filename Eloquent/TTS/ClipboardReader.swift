import AppKit

protocol ClipboardReading: Sendable {
    func string() -> String?
}

struct ClipboardReader: ClipboardReading {
    func string() -> String? {
        let raw = NSPasteboard.general.string(forType: .string) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
