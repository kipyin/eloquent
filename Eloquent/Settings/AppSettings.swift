import Combine
import Foundation

enum TTSDefaults {
    static let engine = "openai"
    static let endpoint = ""
    static let model = "tts-1"
    static let voice = "alloy"
    static let speed = 1.1
    static let minimumSpeed = 0.7
    static let maximumSpeed = 1.5

    static let paragraphSplit = ParagraphSplitMode.default

    static func clampSpeed(_ value: Double) -> Double {
        let clamped = min(max(value, minimumSpeed), maximumSpeed)
        return (clamped * 10).rounded() / 10
    }
}

struct SettingsSnapshot: Sendable, Equatable {
    var engine: String
    var endpoint: String
    var apiKey: String
    var model: String
    var voice: String
    var speed: Double
    var paragraphSplit: ParagraphSplitMode
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    typealias Defaults = TTSDefaults

    private enum Keys {
        static let engine = "engine"
        static let endpoint = "endpoint"
        static let model = "model"
        static let voice = "voice"
        static let speed = "speed"
        static let paragraphSplit = "paragraphSplit"
    }

    @Published var engine: String {
        didSet { UserDefaults.standard.set(engine, forKey: Keys.engine) }
    }

    @Published var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: Keys.endpoint) }
    }

    @Published var apiKey: String {
        didSet { KeychainStore.saveAPIKey(apiKey) }
    }

    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }

    @Published var voice: String {
        didSet { UserDefaults.standard.set(voice, forKey: Keys.voice) }
    }

    @Published var speed: Double {
        didSet {
            let clamped = Self.clampSpeed(speed)
            if clamped != speed {
                speed = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.speed)
        }
    }

    @Published var paragraphSplit: ParagraphSplitMode {
        didSet { UserDefaults.standard.set(paragraphSplit.rawValue, forKey: Keys.paragraphSplit) }
    }

    private init() {
        let defaults = UserDefaults.standard
        engine = Self.nonEmpty(defaults.string(forKey: Keys.engine), fallback: Defaults.engine)
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
        apiKey = KeychainStore.loadAPIKey()
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            engine: engine.trimmingCharacters(in: .whitespacesAndNewlines),
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            voice: voice.trimmingCharacters(in: .whitespacesAndNewlines),
            speed: TTSDefaults.clampSpeed(speed),
            paragraphSplit: paragraphSplit
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
    }

    static func clampSpeed(_ value: Double) -> Double {
        TTSDefaults.clampSpeed(value)
    }

    private static func nonEmpty(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
