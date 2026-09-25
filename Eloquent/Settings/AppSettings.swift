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

    static func normalizedEndpoint(_ endpoint: String) -> String {
        var base = endpoint.nonEmptyTrimmed ?? ""
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base
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

struct SettingsSnapshot: Sendable {
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
            let clamped = TTSDefaults.clampSpeed(speed)
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
        engine = Self.storedEnum(
            defaults.string(forKey: Keys.engine)?.nonEmptyTrimmed,
            fallback: .openai
        )
        endpoint = defaults.string(forKey: Keys.endpoint)?.nonEmptyTrimmed ?? TTSDefaults.endpoint
        model = defaults.string(forKey: Keys.model)?.nonEmptyTrimmed ?? TTSDefaults.model
        voice = defaults.string(forKey: Keys.voice)?.nonEmptyTrimmed ?? TTSDefaults.voice
        if let storedSpeed = defaults.object(forKey: Keys.speed) as? Double {
            speed = TTSDefaults.clampSpeed(storedSpeed)
        } else {
            speed = TTSDefaults.speed
        }
        paragraphSplit = Self.storedEnum(
            defaults.string(forKey: Keys.paragraphSplit),
            fallback: TTSDefaults.paragraphSplit
        )
        speakHotkey = HotkeyBinding.fromStored(
            keyCode: defaults.object(forKey: Keys.speakHotkeyKeyCode) as? Int,
            modifiers: defaults.object(forKey: Keys.speakHotkeyModifiers) as? Int
        )
        speedApply = Self.storedEnum(
            defaults.string(forKey: Keys.speedApply),
            fallback: TTSDefaults.speedApply
        )
        apiKey = secrets.loadAPIKey()
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            engine: engine,
            endpoint: endpoint.nonEmptyTrimmed ?? "",
            apiKey: apiKey.nonEmptyTrimmed ?? "",
            model: model.nonEmptyTrimmed ?? "",
            voice: voice.nonEmptyTrimmed ?? "",
            speed: speed,
            paragraphSplit: paragraphSplit,
            speedApply: speedApply
        )
    }

    func resetToDefaults() {
        engine = TTSDefaults.engine
        endpoint = TTSDefaults.endpoint
        apiKey = ""
        model = TTSDefaults.model
        voice = TTSDefaults.voice
        speed = TTSDefaults.speed
        paragraphSplit = TTSDefaults.paragraphSplit
        speakHotkey = .optionEscape
        speedApply = TTSDefaults.speedApply
    }

    private func applyEngineSwitch(from old: Engine, to new: Engine) {
        guard old != new else { return }
        voice = new.defaultVoice
        if Engine.normalizedEndpoint(endpoint) == old.officialEndpoint {
            endpoint = new.officialEndpoint
        }
    }

    private static func storedEnum<T: RawRepresentable>(
        _ value: String?,
        fallback: T
    ) -> T where T.RawValue == String {
        guard let value, let stored = T(rawValue: value) else {
            return fallback
        }
        return stored
    }
}
