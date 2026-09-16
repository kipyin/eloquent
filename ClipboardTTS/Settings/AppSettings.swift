import Combine
import Foundation

enum TTSDefaults {
    static let engine = "openai"
    static let endpoint = "http://127.0.0.1:8787/v1"
    static let model = "grok-tts"
    static let voice = "carina"
    static let speed = 1.1
    static let minimumSpeed = 0.7
    static let maximumSpeed = 1.5

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
        apiKey = KeychainStore.loadAPIKey()
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            engine: engine.trimmingCharacters(in: .whitespacesAndNewlines),
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            voice: voice.trimmingCharacters(in: .whitespacesAndNewlines),
            speed: TTSDefaults.clampSpeed(speed)
        )
    }

    func resetToDefaults() {
        engine = Defaults.engine
        endpoint = Defaults.endpoint
        apiKey = ""
        model = Defaults.model
        voice = Defaults.voice
        speed = Defaults.speed
    }

    static func clampSpeed(_ value: Double) -> Double {
        TTSDefaults.clampSpeed(value)
    }

    private static func nonEmpty(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
