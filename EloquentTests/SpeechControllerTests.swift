import XCTest
@testable import Eloquent

@MainActor
final class SpeechControllerTests: XCTestCase {
    func testEmptyClipboardFailsWithoutFloatingPanel() {
        let speech = makeSpeech(clipboard: StubClipboard(text: nil))

        speech.speakClipboard()

        XCTAssertEqual(speech.state, .failed("Clipboard is empty."))
        XCTAssertFalse(speech.showsFloatingPanel)
        XCTAssertTrue(speech.paragraphs.isEmpty)
    }

    func testEmptyEndpointFailsWithoutFloatingPanel() {
        let speech = makeSpeech(
            clipboard: StubClipboard(text: "Hello"),
            settings: StubSettings(makeSnapshot(endpoint: ""))
        )

        speech.speakClipboard()

        XCTAssertEqual(speech.state, .failed(TTSError.missingEndpoint.localizedDescription))
        XCTAssertFalse(speech.showsFloatingPanel)
    }

    func testSpeakSplitsOnParagraphModeAndPlays() async {
        let synthesizer = FakeSynthesizer()
        let player = FakePlayer()
        let text = "First\n\nSecond"
        let speech = makeSpeech(
            synthesizer: synthesizer,
            player: player,
            clipboard: StubClipboard(text: text),
            settings: StubSettings(makeSnapshot(paragraphSplit: .blankLinesOnly))
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }

        XCTAssertEqual(speech.paragraphs, ["First", "Second"])
        XCTAssertEqual(speech.index, 0)
        XCTAssertEqual(synthesizer.texts, ["First"])
        XCTAssertEqual(player.playCount, 1)
        XCTAssertTrue(speech.showsFloatingPanel)
        XCTAssertTrue(speech.canGoNext)
        XCTAssertFalse(speech.canGoPrevious)
        XCTAssertEqual(speech.progressLabel, "Paragraph 1 of 2")
    }

    func testSuccessfulFinishAdvancesToNextParagraphThenStops() async {
        let synthesizer = FakeSynthesizer()
        let player = FakePlayer()
        let speech = makeSpeech(
            synthesizer: synthesizer,
            player: player,
            clipboard: StubClipboard(text: "One\n\nTwo"),
            settings: StubSettings(makeSnapshot(paragraphSplit: .blankLinesOnly))
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        player.finishSuccessfully()
        await waitUntil { speech.index == 1 && speech.state == .playing }

        XCTAssertEqual(synthesizer.texts, ["One", "Two"])
        XCTAssertEqual(speech.progressLabel, "Paragraph 2 of 2")

        player.finishSuccessfully()
        await waitUntil { speech.state == .idle }

        XCTAssertEqual(speech.state, .idle)
        XCTAssertTrue(speech.paragraphs.isEmpty)
        XCTAssertFalse(speech.showsFloatingPanel)
    }

    func testNextAndPreviousResynthesizeTheTargetParagraph() async {
        let synthesizer = FakeSynthesizer()
        let player = FakePlayer()
        let speech = makeSpeech(
            synthesizer: synthesizer,
            player: player,
            clipboard: StubClipboard(text: "One\n\nTwo\n\nThree"),
            settings: StubSettings(makeSnapshot(paragraphSplit: .blankLinesOnly))
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        speech.next()
        await waitUntil { speech.index == 1 && speech.state == .playing }

        XCTAssertEqual(speech.index, 1)
        XCTAssertEqual(synthesizer.texts.last, "Two")

        speech.previous()
        await waitUntil { speech.index == 0 && speech.state == .playing && synthesizer.texts.last == "One" }

        XCTAssertEqual(speech.index, 0)
        XCTAssertEqual(synthesizer.texts.last, "One")
    }

    func testPauseAndResumeStayOnTheSameParagraph() async {
        let player = FakePlayer()
        let speech = makeSpeech(
            player: player,
            clipboard: StubClipboard(text: "Hello")
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        speech.togglePause()

        XCTAssertEqual(speech.state, .paused)
        XCTAssertEqual(player.pauseCount, 1)
        XCTAssertTrue(speech.isPaused)

        speech.togglePause()
        XCTAssertEqual(speech.state, .playing)
        XCTAssertEqual(player.resumeCount, 1)
    }

    func testStopClearsSession() async {
        let speech = makeSpeech(clipboard: StubClipboard(text: "Hello"))

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        speech.stop()

        XCTAssertEqual(speech.state, .idle)
        XCTAssertTrue(speech.paragraphs.isEmpty)
        XCTAssertFalse(speech.canStop)
        XCTAssertFalse(speech.showsFloatingPanel)
    }

    func testNextParagraphSpeedChangeDoesNotInterruptCurrentParagraph() async {
        let synthesizer = FakeSynthesizer()
        let player = FakePlayer()
        let settings = StubSettings(
            makeSnapshot(speed: 1.1, paragraphSplit: .blankLinesOnly, speedApply: .nextParagraph)
        )
        let speech = makeSpeech(
            synthesizer: synthesizer,
            player: player,
            clipboard: StubClipboard(text: "One\n\nTwo"),
            settings: settings
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        settings.value.speed = 1.4
        speech.applySpeedChange()

        XCTAssertEqual(speech.state, .playing)
        XCTAssertEqual(speech.index, 0)
        XCTAssertEqual(synthesizer.texts, ["One"])
        XCTAssertEqual(synthesizer.speeds, [1.1])
        XCTAssertEqual(player.stopCount, 1)

        player.finishSuccessfully()
        await waitUntil { speech.index == 1 && speech.state == .playing }

        XCTAssertEqual(synthesizer.texts, ["One", "Two"])
        XCTAssertEqual(synthesizer.speeds, [1.1, 1.4])
    }

    func testRespeakSpeedChangeSynthesizesTheCurrentParagraphAgain() async {
        let synthesizer = FakeSynthesizer()
        let player = FakePlayer()
        let settings = StubSettings(
            makeSnapshot(speed: 1.1, paragraphSplit: .blankLinesOnly, speedApply: .respeakCurrent)
        )
        let speech = makeSpeech(
            synthesizer: synthesizer,
            player: player,
            clipboard: StubClipboard(text: "One\n\nTwo"),
            settings: settings
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        settings.value.speed = 1.4
        speech.applySpeedChange()
        await waitUntil { synthesizer.texts == ["One", "One"] && speech.state == .playing }

        XCTAssertEqual(speech.index, 0)
        XCTAssertEqual(synthesizer.texts, ["One", "One"])
        XCTAssertEqual(synthesizer.speeds, [1.1, 1.4])
        XCTAssertEqual(player.stopCount, 2)
        XCTAssertTrue(speech.showsFloatingPanel)
    }

    func testRespeakDoesNotRestartWhenSpeedIsUnchanged() async {
        let synthesizer = FakeSynthesizer()
        let player = FakePlayer()
        let settings = StubSettings(
            makeSnapshot(speed: 1.1, paragraphSplit: .blankLinesOnly, speedApply: .respeakCurrent)
        )
        let speech = makeSpeech(
            synthesizer: synthesizer,
            player: player,
            clipboard: StubClipboard(text: "One"),
            settings: settings
        )

        speech.speakClipboard()
        await waitUntil { speech.state == .playing }
        speech.applySpeedChange()

        XCTAssertEqual(speech.state, .playing)
        XCTAssertEqual(synthesizer.texts, ["One"])
        XCTAssertEqual(synthesizer.speeds, [1.1])
        XCTAssertEqual(player.stopCount, 1)
    }

    func testSynthesisFailureKeepsFloatingPanelForTheSession() async {
        let synthesizer = FakeSynthesizer()
        synthesizer.result = .failure(TTSError.http(500, "boom"))
        let speech = makeSpeech(
            synthesizer: synthesizer,
            clipboard: StubClipboard(text: "Hello")
        )

        speech.speakClipboard()
        await waitUntil {
            if case .failed = speech.state { return true }
            return false
        }

        XCTAssertEqual(speech.state, .failed("TTS HTTP 500: boom"))
        XCTAssertEqual(speech.paragraphs, ["Hello"])
        XCTAssertTrue(speech.showsFloatingPanel)
    }

    func testInvalidEndpointFailsInsideTheSpeechSession() async {
        let transport = FakeHTTPTransport { _ in
            XCTFail("Transport should not run for an invalid endpoint")
            throw TTSError.invalidResponse
        }
        let speech = makeSpeech(
            synthesizer: TTSClient(transport: transport),
            clipboard: StubClipboard(text: "Hello"),
            settings: StubSettings(makeSnapshot(endpoint: "///"))
        )

        speech.speakClipboard()
        await waitUntil {
            if case .failed = speech.state { return true }
            return false
        }

        XCTAssertEqual(speech.state, .failed(TTSError.invalidEndpoint("///").localizedDescription))
        XCTAssertEqual(speech.paragraphs, ["Hello"])
        XCTAssertTrue(speech.showsFloatingPanel)
    }

    private func makeSpeech(
        synthesizer: any TTSSynthesizing = FakeSynthesizer(),
        player: FakePlayer = FakePlayer(),
        clipboard: StubClipboard = StubClipboard(text: "Hello"),
        settings: StubSettings? = nil
    ) -> SpeechController {
        SpeechController(
            synthesizer: synthesizer,
            player: player,
            clipboard: clipboard,
            settings: settings ?? StubSettings(makeSnapshot())
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() {
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Condition not met before timeout", file: file, line: line)
    }
}
