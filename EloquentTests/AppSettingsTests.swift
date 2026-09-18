import XCTest
@testable import Eloquent

@MainActor
final class AppSettingsTests: XCTestCase {
    func testPublicDefaultsWhenStoreIsEmpty() {
        let (settings, _, secrets) = makeSettings()

        XCTAssertEqual(settings.engine, .openai)
        XCTAssertEqual(settings.endpoint, "")
        XCTAssertEqual(settings.model, "tts-1")
        XCTAssertEqual(settings.voice, "alloy")
        XCTAssertEqual(settings.speed, 1.1, accuracy: 0.0001)
        XCTAssertEqual(settings.paragraphSplit, .blankLinesThenNewlines)
        XCTAssertEqual(settings.speakHotkey, .optionEscape)
        XCTAssertEqual(settings.speedApply, .nextParagraph)
        XCTAssertEqual(settings.apiKey, "")
        XCTAssertEqual(secrets.value, "")
    }

    func testBlankStoredStringsFallBackExceptEmptyEndpoint() throws {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("  ", forKey: "engine")
        defaults.set("  ", forKey: "endpoint")
        defaults.set("  ", forKey: "model")
        defaults.set("  ", forKey: "voice")

        let settings = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())

        XCTAssertEqual(settings.engine, .openai)
        XCTAssertEqual(settings.endpoint, "")
        XCTAssertEqual(settings.model, "tts-1")
        XCTAssertEqual(settings.voice, "alloy")

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testUnknownStoredEngineFallsBackToOpenAI() throws {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("custom", forKey: "engine")
        defaults.set("nova", forKey: "voice")
        defaults.set("https://proxy.example.com/v1", forKey: "endpoint")

        let settings = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())

        XCTAssertEqual(settings.engine, .openai)
        XCTAssertEqual(settings.voice, "nova")
        XCTAssertEqual(settings.endpoint, "https://proxy.example.com/v1")
        XCTAssertEqual(settings.snapshot().engine, .openai)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testEnginePersistsRawValue() {
        let (settings, defaults, _) = makeSettings()
        settings.engine = .grok

        XCTAssertEqual(defaults.string(forKey: "engine"), "grok")

        let reloaded = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.engine, .grok)
    }

    func testSwitchingEngineResetsVoiceToEngineDefault() {
        let (settings, _, _) = makeSettings()
        settings.voice = "nova"

        settings.engine = .grok
        XCTAssertEqual(settings.voice, "eve")

        settings.engine = .openai
        XCTAssertEqual(settings.voice, "alloy")
    }

    func testOfficialEndpointIsReplacedOnEngineSwitch() {
        let (settings, _, _) = makeSettings()
        settings.endpoint = "https://api.openai.com/v1"

        settings.engine = .grok
        XCTAssertEqual(settings.endpoint, "https://api.x.ai/v1")

        settings.engine = .openai
        XCTAssertEqual(settings.endpoint, "https://api.openai.com/v1")
    }

    func testCustomEndpointSurvivesEngineSwitchRoundTrip() {
        let (settings, _, _) = makeSettings()
        settings.endpoint = "https://proxy.example.com/v1"

        settings.engine = .grok
        XCTAssertEqual(settings.endpoint, "https://proxy.example.com/v1")

        settings.engine = .openai
        XCTAssertEqual(settings.endpoint, "https://proxy.example.com/v1")
    }

    func testSnapshotTrimsAndClampsSpeed() {
        let (settings, _, _) = makeSettings()
        settings.endpoint = "  https://api.example.com/v1/  "
        settings.model = "  tts-1  "
        settings.voice = "  alloy  "
        settings.apiKey = "  sk-test  "
        settings.speed = 1.55

        let snapshot = settings.snapshot()
        XCTAssertEqual(snapshot.endpoint, "https://api.example.com/v1/")
        XCTAssertEqual(snapshot.model, "tts-1")
        XCTAssertEqual(snapshot.voice, "alloy")
        XCTAssertEqual(snapshot.apiKey, "sk-test")
        XCTAssertEqual(snapshot.speed, 1.5, accuracy: 0.0001)
        XCTAssertEqual(settings.speed, 1.5, accuracy: 0.0001)
    }

    func testSpeedFloorIsPointSeven() {
        let (settings, _, _) = makeSettings()
        settings.speed = 0.65
        XCTAssertEqual(settings.speed, 0.7, accuracy: 0.0001)
    }

    func testAPIKeyPersistsToSecretStoreNotDefaults() {
        let (settings, defaults, secrets) = makeSettings()
        settings.apiKey = "sk-secret"

        XCTAssertEqual(secrets.value, "sk-secret")
        XCTAssertNil(defaults.string(forKey: "apiKey"))
        XCTAssertNil(defaults.string(forKey: "api-key"))
    }

    func testParagraphSplitPersistsRawValue() {
        let (settings, defaults, _) = makeSettings()
        settings.paragraphSplit = .sentences

        XCTAssertEqual(defaults.string(forKey: "paragraphSplit"), "sentences")

        let reloaded = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.paragraphSplit, .sentences)
    }

    func testSpeedApplyPersistsRawValue() {
        let (settings, defaults, _) = makeSettings()
        settings.speedApply = .respeakCurrent

        XCTAssertEqual(defaults.string(forKey: "speedApply"), "respeakCurrent")

        let reloaded = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.speedApply, .respeakCurrent)
    }

    func testResetToDefaultsClearsSecret() {
        let (settings, _, secrets) = makeSettings()
        settings.endpoint = "https://api.example.com/v1"
        settings.apiKey = "sk-secret"
        settings.model = "other"
        settings.voice = "other"
        settings.speed = 0.8
        settings.paragraphSplit = .everyNewline
        settings.speakHotkey = HotkeyBinding(keyCode: 0, modifiers: [.command, .option])
        settings.speedApply = .respeakCurrent

        settings.resetToDefaults()

        XCTAssertEqual(settings.engine, .openai)
        XCTAssertEqual(settings.endpoint, "")
        XCTAssertEqual(settings.apiKey, "")
        XCTAssertEqual(secrets.value, "")
        XCTAssertEqual(settings.model, "tts-1")
        XCTAssertEqual(settings.voice, "alloy")
        XCTAssertEqual(settings.speed, 1.1, accuracy: 0.0001)
        XCTAssertEqual(settings.paragraphSplit, .blankLinesThenNewlines)
        XCTAssertEqual(settings.speakHotkey, .optionEscape)
        XCTAssertEqual(settings.speedApply, .nextParagraph)
    }

    func testSpeakHotkeyPersistsAcrossReload() {
        let (settings, defaults, _) = makeSettings()
        settings.speakHotkey = HotkeyBinding(keyCode: 0, modifiers: [.command, .option])

        let reloaded = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.speakHotkey, HotkeyBinding(keyCode: 0, modifiers: [.command, .option]))
    }

    func testInvalidStoredSpeakHotkeyFallsBackToOptionEscape() {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(-1, forKey: "speakHotkeyKeyCode")
        defaults.set(0, forKey: "speakHotkeyModifiers")

        let settings = AppSettings(defaults: defaults, secrets: MemoryAPIKeyStore())
        XCTAssertEqual(settings.speakHotkey, .optionEscape)

        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeSettings() -> (AppSettings, UserDefaults, MemoryAPIKeyStore) {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let secrets = MemoryAPIKeyStore()
        let settings = AppSettings(defaults: defaults, secrets: secrets)
        return (settings, defaults, secrets)
    }
}
