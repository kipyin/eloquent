import AppKit

struct ClipboardReader: ClipboardReading {
    func string() -> String? {
        return NSPasteboard.general.string(forType: .string)?.nonEmptyTrimmed
    }
}
