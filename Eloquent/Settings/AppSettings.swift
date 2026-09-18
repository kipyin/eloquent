import Combine
import Foundation

enum Engine: String, CaseIterable, Identifiable, Sendable {
    case openai
    case grok

    static let `default` = Engine.openai

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .grok:
            return "Grok"
        }
    }

    var officialEndpoint: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .grok:
            return "https://api.x.ai/v1"
        }
    }

    var defaultVoice: String {
        switch self {
        case .openai:
            return "alloy"
        case .grok:
            return "eve"
        }
    }

    var speechPath: String {
        switch self {
        case .openai:
            return "/audio/speech"
        case .grok:
            return "/tts"
        }
    }
}

enum SpeedApplyMode: String, CaseIterable, Identifiable, Sendable {
    case nextParagraph = "nextParagraph"
    case respeakCurrent = "respeakCurrent"

    static let `default` = SpeedApplyMode.nextParagraph

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .nextParagraph:
            return "Next paragraph only"
        case .respeakCurrent:
            return "Re-speak current paragraph"
        }
    }

    var helpText: String {
        switch self {
        case .nextParagraph:
            return "Keep the current paragraph playing. The new speed is used on the next synthesis."
        case .respeakCurrent:
            return "Cancel the current paragraph and synthesize it again at the new speed."
        }
    }
}

enum TTSDefaults {
    static let engine = Engine.default
    static let endpoint = ""
    static let model = "tts-1"
    static let voice = Engine.openai.defaultVoice
    static let speed = 1.1
    static let minimumSpeed = 0.7
    static let maximumSpeed = 1.5

    static let paragraphSplit = ParagraphSplitMode.default
    static let speedApply = SpeedApplyMode.default

    static func clampSpeed(_ value: Double) -> Double {
        let clamped = min(max(value, minimumSpeed), maximumSpeed)
        return (clamped * 10).rounded() / 10
    }
}

struct SettingsSnapshot: Sendable, Equatable {
    var engine: Engine
    var endpoint: String
    var apiKey: String
    var model: String
    var voice: String
    var speed: Double
    var paragraphSplit: ParagraphSplitMode
    var speedApply: SpeedApplyMode
}

@MainActor
protocol SettingsProviding: AnyObject {
    func snapshot() -> SettingsSnapshot
}

@MainActor
final class AppSettings: ObservableObject, SettingsProviding {
    static let shared = AppSettings()

    typealias Defaults = TTSDefaults

    private enum Keys {
        static let engine = "engine"
        static let endpoint = "endpoint"
        static let model = "model"
        static let voice = "voice"
        static let speed = "speed"
        static let paragraphSplit = "paragraphSplit"
        static let speakHotkeyKeyCode = "speakHotkeyKeyCode"
        static let speakHotkeyModifiers = "speakHotkeyModifiers"
        static let speedApply = "speedApply"
    }

    private let defaults: UserDefaults
    private let secrets: any APIKeyStoring

    @Published var engine: Engine {
        didSet {
            defaults.set(engine.rawValue, forKey: Keys.engine)
            applyEngineSwitch(from: oldValue, to: engine)
        }
    }

    @Published var endpoint: String {
        didSet { defaults.set(endpoint, forKey: Keys.endpoint) }
    }

    @Published var apiKey: String {
        didSet { secrets.saveAPIKey(apiKey) }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var voice: String {
        didSet { defaults.set(voice, forKey: Keys.voice) }
    }

    @Published var speed: Double {
        didSet {
            let clamped = Self.clampSpeed(speed)
            if clamped != speed {
                speed = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.speed)
        }
    }

    @Published var paragraphSplit: ParagraphSplitMode {
        didSet { defaults.set(paragraphSplit.rawValue, forKey: Keys.paragraphSplit) }
    }

    @Published var speakHotkey: HotkeyBinding {
        didSet {
            defaults.set(Int(speakHotkey.keyCode), forKey: Keys.speakHotkeyKeyCode)
            defaults.set(Int(speakHotkey.modifiers.rawValue), forKey: Keys.speakHotkeyModifiers)
        }
    }

    @Published var speedApply: SpeedApplyMode {
        didSet { defaults.set(speedApply.rawValue, forKey: Keys.speedApply) }
    }

    init(defaults: UserDefaults = .standard, secrets: any APIKeyStoring = KeychainStore()) {
        self.defaults = defaults
        self.secrets = secrets
        engine = Self.storedEngine(defaults.string(forKey: Keys.engine))
        endpoint = Self.nonEmpty(defaults.string(forKey: Keys.endpoint), fallback: Defaults.endpoint)
        model = Self.nonEmpty(defaults.string(forKey: Keys.model), fallback: Defaults.model)
        voice = Self.nonEmpty(defaults.string(forKey: Keys.voice), fallback: Defaults.voice)
        if let storedSpeed = defaults.object(forKey: Keys.speed) as? Double {
            speed = Self.clampSpeed(storedSpeed)
        } else {
            speed = Defaults.speed
        }
        if let raw = defaults.string(forKey: Keys.paragraphSplit),
           let stored = ParagraphSplitMode(rawValue: raw) {
            paragraphSplit = stored
        } else {
            paragraphSplit = Defaults.paragraphSplit
        }
        speakHotkey = HotkeyBinding.fromStored(
            keyCode: defaults.object(forKey: Keys.speakHotkeyKeyCode) as? Int,
            modifiers: defaults.object(forKey: Keys.speakHotkeyModifiers) as? Int
        )
        if let raw = defaults.string(forKey: Keys.speedApply),
           let stored = SpeedApplyMode(rawValue: raw) {
            speedApply = stored
        } else {
            speedApply = Defaults.speedApply
        }
        apiKey = secrets.loadAPIKey()
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            engine: engine,
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            voice: voice.trimmingCharacters(in: .whitespacesAndNewlines),
            speed: TTSDefaults.clampSpeed(speed),
            paragraphSplit: paragraphSplit,
            speedApply: speedApply
        )
    }

    func resetToDefaults() {
        engine = Defaults.engine
        endpoint = Defaults.endpoint
        apiKey = ""
        model = Defaults.model
        voice = Defaults.voice
        speed = Defaults.speed
        paragraphSplit = Defaults.paragraphSplit
        speakHotkey = .optionEscape
        speedApply = Defaults.speedApply
    }

    static func clampSpeed(_ value: Double) -> Double {
        TTSDefaults.clampSpeed(value)
    }

    private func applyEngineSwitch(from old: Engine, to new: Engine) {
        guard old != new else { return }
        voice = new.defaultVoice
        if endpoint.trimmingCharacters(in: .whitespacesAndNewlines) == old.officialEndpoint {
            endpoint = new.officialEndpoint
        }
    }

    private static func storedEngine(_ value: String?) -> Engine {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Engine(rawValue: trimmed) ?? .openai
    }

    private static func nonEmpty(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
