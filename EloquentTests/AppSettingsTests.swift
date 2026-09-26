import XCTest

@MainActor
final class AppSettingsTests: XCTestCase {
    func testPublicDefaultsWhenStoreIsEmpty() {
        let (settings, _, store) = makeSettings()

        XCTAssertEqual(settings.engine, .openai)
        XCTAssertEqual(settings.endpoint, "")
        XCTAssertEqual(settings.model, "tts-1")
        XCTAssertEqual(settings.voice, "alloy")
        XCTAssertEqual(settings.speed, 1.1, accuracy: 0.0001)
        XCTAssertEqual(settings.paragraphSplit, .blankLinesThenNewlines)
        XCTAssertEqual(settings.speakHotkey, .optionEscape)
        XCTAssertEqual(settings.speedApply, .nextParagraph)
        XCTAssertEqual(settings.apiKey, "")
        XCTAssertNil(store.value)
    }

    func testBlankStoredStringsFallBackExceptEmptyEndpoint() throws {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("  ", forKey: "engine")
        defaults.set("  ", forKey: "endpoint")
        defaults.set("  ", forKey: "model")
        defaults.set("  ", forKey: "voice")

        let settings = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())

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

        let settings = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())

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

        let reloaded = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())
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

    func testOfficialEndpointWithTrailingSlashesIsReplacedOnEngineSwitch() {
        let (settings, _, _) = makeSettings()
        settings.endpoint = "https://api.openai.com/v1//"

        settings.engine = .grok
        XCTAssertEqual(settings.endpoint, "https://api.x.ai/v1")
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

    func testAPIKeyPersistsWithUserSettings() {
        let (settings, defaults, _) = makeSettings()
        settings.apiKey = "sk-secret"

        XCTAssertEqual(defaults.string(forKey: "apiKey"), "sk-secret")

        let reloaded = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.apiKey, "sk-secret")
    }

    func testLaunchMigrationCopiesKeychainKeyIntoSettingsAndDeletesItem() {
        let defaults = makeDefaults()
        let store = MemoryAPIKeyStore()
        store.value = "sk-legacy"

        let settings = AppSettings(defaults: defaults, legacyStore: store)

        XCTAssertEqual(settings.apiKey, "sk-legacy")
        XCTAssertEqual(defaults.string(forKey: "apiKey"), "sk-legacy")
        XCTAssertEqual(store.deleteCount, 1)
    }

    func testFailedKeychainDeleteDoesNotRerunMigration() {
        // MemoryAPIKeyStore keeps `value` on delete, modelling a failed delete:
        // the item stays in the Keychain.
        let defaults = makeDefaults()
        let store = MemoryAPIKeyStore()
        store.value = "sk-legacy"

        _ = AppSettings(defaults: defaults, legacyStore: store)
        XCTAssertEqual(store.deleteCount, 1)
        XCTAssertNotNil(store.value)

        let reloaded = AppSettings(defaults: defaults, legacyStore: store)
        XCTAssertEqual(reloaded.apiKey, "sk-legacy")
        XCTAssertEqual(store.loadCount, 1)
        XCTAssertEqual(store.deleteCount, 1)
    }

    func testDeniedKeychainReadLeavesKeyEmptyAndRetriesNextLaunch() {
        let defaults = makeDefaults()
        let store = MemoryAPIKeyStore()

        let settings = AppSettings(defaults: defaults, legacyStore: store)

        XCTAssertEqual(settings.apiKey, "")
        XCTAssertNil(defaults.string(forKey: "apiKey"))
        XCTAssertEqual(store.deleteCount, 0)

        store.value = "sk-legacy"
        let retried = AppSettings(defaults: defaults, legacyStore: store)
        XCTAssertEqual(retried.apiKey, "sk-legacy")
        XCTAssertEqual(store.loadCount, 2)
    }

    func testUserSavedKeyIsNotReplacedByKeychainValue() {
        let (settings, defaults, _) = makeSettings()
        settings.apiKey = "sk-user"

        let store = MemoryAPIKeyStore()
        store.value = "sk-legacy"
        let reloaded = AppSettings(defaults: defaults, legacyStore: store)

        XCTAssertEqual(reloaded.apiKey, "sk-user")
        XCTAssertEqual(store.loadCount, 0)
        XCTAssertEqual(store.deleteCount, 0)
    }

    func testClearedKeyStaysEmptyAndSkipsMigration() {
        let (settings, defaults, _) = makeSettings()
        settings.apiKey = "sk-user"
        settings.apiKey = ""

        let store = MemoryAPIKeyStore()
        store.value = "sk-legacy"
        let reloaded = AppSettings(defaults: defaults, legacyStore: store)

        XCTAssertEqual(reloaded.apiKey, "")
        XCTAssertEqual(store.loadCount, 0)
        XCTAssertEqual(store.deleteCount, 0)
    }

    func testResetDefaultsStaysEmptyAndSkipsMigration() {
        let (settings, defaults, _) = makeSettings()
        settings.apiKey = "sk-secret"
        settings.resetToDefaults()

        let store = MemoryAPIKeyStore()
        store.value = "sk-legacy"
        let reloaded = AppSettings(defaults: defaults, legacyStore: store)

        XCTAssertEqual(reloaded.apiKey, "")
        XCTAssertEqual(store.loadCount, 0)
        XCTAssertEqual(store.deleteCount, 0)
    }

    func testParagraphSplitPersistsRawValue() {
        let (settings, defaults, _) = makeSettings()
        settings.paragraphSplit = .sentences

        XCTAssertEqual(defaults.string(forKey: "paragraphSplit"), "sentences")

        let reloaded = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.paragraphSplit, .sentences)
    }

    func testSpeedApplyPersistsRawValue() {
        let (settings, defaults, _) = makeSettings()
        settings.speedApply = .respeakCurrent

        XCTAssertEqual(defaults.string(forKey: "speedApply"), "respeakCurrent")

        let reloaded = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.speedApply, .respeakCurrent)
    }

    func testResetToDefaultsClearsAPIKey() {
        let (settings, defaults, _) = makeSettings()
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
        XCTAssertEqual(defaults.string(forKey: "apiKey"), "")
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

        let reloaded = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())
        XCTAssertEqual(reloaded.speakHotkey, HotkeyBinding(keyCode: 0, modifiers: [.command, .option]))
    }

    func testInvalidStoredSpeakHotkeyFallsBackToOptionEscape() {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(-1, forKey: "speakHotkeyKeyCode")
        defaults.set(0, forKey: "speakHotkeyModifiers")

        let settings = AppSettings(defaults: defaults, legacyStore: MemoryAPIKeyStore())
        XCTAssertEqual(settings.speakHotkey, .optionEscape)

        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeSettings() -> (AppSettings, UserDefaults, MemoryAPIKeyStore) {
        let defaults = makeDefaults()
        let store = MemoryAPIKeyStore()
        let settings = AppSettings(defaults: defaults, legacyStore: store)
        return (settings, defaults, store)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.kipyin.eloquent.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
