import AppKit

extension HotkeyModifiers {
    init(eventFlags: NSEvent.ModifierFlags) {
        var value = HotkeyModifiers()
        let flags = eventFlags.intersection([.command, .shift, .control, .option])
        if flags.contains(.command) { value.insert(.command) }
        if flags.contains(.shift) { value.insert(.shift) }
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.option) { value.insert(.option) }
        self = value
    }

    var nsEventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.shift) { flags.insert(.shift) }
        if contains(.control) { flags.insert(.control) }
        if contains(.option) { flags.insert(.option) }
        return flags
    }

    var carbon: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= 0x0100 }
        if contains(.shift) { value |= 0x0200 }
        if contains(.option) { value |= 0x0800 }
        if contains(.control) { value |= 0x1000 }
        return value
    }
}

extension HotkeyBinding {
    init(event: NSEvent) {
        self.init(keyCode: event.keyCode, modifiers: HotkeyModifiers(eventFlags: event.modifierFlags))
    }

    func matches(_ event: NSEvent) -> Bool {
        keyCode == event.keyCode && modifiers == HotkeyModifiers(eventFlags: event.modifierFlags)
    }

    var carbonKeyCode: UInt32 {
        UInt32(keyCode)
    }

    var carbonModifiers: UInt32 {
        modifiers.carbon
    }

    var menuModifierFlags: NSEvent.ModifierFlags {
        modifiers.nsEventFlags
    }

    var menuKeyEquivalent: String {
        switch keyCode {
        case 36: return "\r"
        case 48: return "\t"
        case 49: return " "
        case 51: return "\u{8}"
        case 53: return "\u{1b}"
        case 122: return Self.functionKey(NSF1FunctionKey)
        case 120: return Self.functionKey(NSF2FunctionKey)
        case 99: return Self.functionKey(NSF3FunctionKey)
        case 118: return Self.functionKey(NSF4FunctionKey)
        case 96: return Self.functionKey(NSF5FunctionKey)
        case 97: return Self.functionKey(NSF6FunctionKey)
        case 98: return Self.functionKey(NSF7FunctionKey)
        case 100: return Self.functionKey(NSF8FunctionKey)
        case 101: return Self.functionKey(NSF9FunctionKey)
        case 109: return Self.functionKey(NSF10FunctionKey)
        case 103: return Self.functionKey(NSF11FunctionKey)
        case 111: return Self.functionKey(NSF12FunctionKey)
        case 123: return Self.functionKey(NSLeftArrowFunctionKey)
        case 124: return Self.functionKey(NSRightArrowFunctionKey)
        case 125: return Self.functionKey(NSDownArrowFunctionKey)
        case 126: return Self.functionKey(NSUpArrowFunctionKey)
        default:
            let name = keyName
            guard name.count == 1 else {
                return ""
            }
            return name.lowercased()
        }
    }

    var menuTitle: String {
        if menuKeyEquivalent.isEmpty {
            return "Speak Clipboard (\(displayLabel))"
        }
        return "Speak Clipboard"
    }

    private static func functionKey(_ key: Int) -> String {
        String(utf16CodeUnits: [unichar(key)], count: 1)
    }
}
