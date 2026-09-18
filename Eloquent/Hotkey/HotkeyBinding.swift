import Foundation

struct HotkeyModifiers: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    static let command = HotkeyModifiers(rawValue: 1 << 0)
    static let option = HotkeyModifiers(rawValue: 1 << 1)
    static let control = HotkeyModifiers(rawValue: 1 << 2)
    static let shift = HotkeyModifiers(rawValue: 1 << 3)

    var hasNonShiftModifier: Bool {
        !intersection([.command, .option, .control]).isEmpty
    }
}

enum HotkeyRejection: Equatable, Sendable {
    case incomplete
    case reserved

    var message: String {
        switch self {
        case .incomplete:
            return "Add a key and at least one of Command, Option, or Control."
        case .reserved:
            return "That shortcut is reserved by macOS."
        }
    }
}

struct HotkeyBinding: Hashable, Sendable {
    static let escapeKeyCode: UInt16 = 53

    var keyCode: UInt16
    var modifiers: HotkeyModifiers

    init(keyCode: UInt16, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    static let optionEscape = HotkeyBinding(keyCode: escapeKeyCode, modifiers: .option)

    static func fromStored(keyCode: Int?, modifiers: Int?) -> HotkeyBinding {
        guard let keyCode, let modifiers,
              keyCode >= 0, keyCode <= Int(UInt16.max),
              modifiers >= 0, modifiers <= Int(UInt8.max)
        else {
            return .optionEscape
        }
        return HotkeyBinding(
            keyCode: UInt16(keyCode),
            modifiers: HotkeyModifiers(rawValue: UInt8(modifiers))
        )
    }

    var rejection: HotkeyRejection? {
        if !modifiers.hasNonShiftModifier {
            return .incomplete
        }
        if Self.reserved.contains(self) {
            return .reserved
        }
        return nil
    }

    var displayLabel: String {
        "\(symbolLabel)  \(words)"
    }

    var words: String {
        (modifierWords + [keyWords]).joined(separator: "+")
    }

    var symbolLabel: String {
        modifierSymbols + keySymbol
    }

    var keyName: String {
        Self.keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let reserved: Set<HotkeyBinding> = [
        HotkeyBinding(keyCode: 49, modifiers: .command),
        HotkeyBinding(keyCode: 48, modifiers: .command),
        HotkeyBinding(keyCode: 48, modifiers: [.command, .shift]),
        HotkeyBinding(keyCode: escapeKeyCode, modifiers: [.command, .option]),
        HotkeyBinding(keyCode: 12, modifiers: .command),
    ]

    private var modifierWords: [String] {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }
        return parts
    }

    private var modifierSymbols: String {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        return symbols
    }

    private var keyWords: String {
        keyName
    }

    private var keySymbol: String {
        Self.keySymbols[keyCode] ?? keyWords
    }

    private static let keyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J",
        39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "Left Arrow", 124: "Right Arrow", 125: "Down Arrow", 126: "Up Arrow",
    ]

    private static let keySymbols: [UInt16: String] = [
        36: "↩",
        48: "⇥",
        49: "Space",
        51: "⌫",
        53: "⎋",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
    ]
}
