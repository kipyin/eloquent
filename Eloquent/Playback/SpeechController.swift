import Combine
import Foundation
import os.log

@MainActor
final class SpeechController: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var paragraphs: [String] = []
    @Published private(set) var index: Int = 0

    private let synthesizer: any TTSSynthesizing
    private let player: any AudioPlaying
    private let selection: any SelectionReading
    private let clipboard: any ClipboardReading
    private let settingsProvider: any SettingsProviding
    private var speakTask: Task<Void, Never>?
    private var generation = UUID()
    private var transientErrorTask: Task<Void, Never>?
    private let log = Logger(subsystem: "com.kipyin.eloquent", category: "speech")

    init(
        synthesizer: any TTSSynthesizing = TTSClient(),
        player: any AudioPlaying = AudioPlayback(),
        selection: any SelectionReading = SelectionReader(),
        clipboard: any ClipboardReading = ClipboardReader(),
        settings: any SettingsProviding = AppSettings.shared
    ) {
        self.synthesizer = synthesizer
        self.player = player
        self.selection = selection
        self.clipboard = clipboard
        self.settingsProvider = settings
    }

    var canGoPrevious: Bool {
        switch state {
        case .idle:
            return false
        case .loading, .playing, .paused, .failed:
            return index > 0
        }
    }

    var canGoNext: Bool {
        switch state {
        case .idle:
            return false
        case .loading, .playing, .paused, .failed:
            return index + 1 < paragraphs.count
        }
    }

    var canTogglePause: Bool {
        switch state {
        case .playing, .paused:
            return true
        case .idle, .loading, .failed:
            return false
        }
    }

    var canStop: Bool {
        switch state {
        case .idle:
            return false
        case .loading, .playing, .paused, .failed:
            return true
        }
    }

    var showsFloatingPanel: Bool {
        switch state {
        case .loading, .playing, .paused:
            return true
        case .idle:
            return false
        case .failed:
            return !paragraphs.isEmpty
        }
    }

    var isPaused: Bool {
        if case .paused = state {
            return true
        }
        return false
    }

    var progressLabel: String {
        guard !paragraphs.isEmpty else {
            return "Eloquent"
        }
        return "Paragraph \(index + 1) of \(paragraphs.count)"
    }

    var currentPreview: String {
        guard paragraphs.indices.contains(index) else {
            return ""
        }
        let collapsed = paragraphs[index]
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        if collapsed.count <= 140 {
            return collapsed
        }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 140)
        return String(collapsed[..<end]) + "…"
    }

    func speak() {
        guard let text = selection.selectedText() ?? clipboard.string() else {
            presentTransientError("No text selected and clipboard is empty.")
            return
        }

        let settings = settingsProvider.snapshot()
        let parts = ParagraphSplitter.split(text, mode: settings.paragraphSplit)
        guard !parts.isEmpty else {
            presentTransientError("No text selected and clipboard is empty.")
            return
        }

        if settings.endpoint.isEmpty {
            presentTransientError(TTSError.missingEndpoint.localizedDescription)
            return
        }

        beginSession(paragraphs: parts, startingAt: 0)
    }

    func togglePause() {
        switch state {
        case .playing:
            player.pause()
            state = .paused
        case .paused:
            player.resume()
            state = .playing
        case .idle, .loading, .failed:
            break
        }
    }

    func stop() {
        cancelWork()
        player.stop()
        paragraphs = []
        index = 0
        state = .idle
    }

    func previous() {
        guard canGoPrevious else {
            return
        }
        beginSession(paragraphs: paragraphs, startingAt: index - 1)
    }

    func next() {
        guard canGoNext else {
            return
        }
        beginSession(paragraphs: paragraphs, startingAt: index + 1)
    }

    private func beginSession(paragraphs: [String], startingAt startIndex: Int) {
        cancelWork()
        player.stop()
        self.paragraphs = paragraphs
        self.index = startIndex
        speakCurrent()
    }

    private func speakCurrent() {
        guard paragraphs.indices.contains(index) else {
            stop()
            return
        }

        let token = UUID()
        generation = token
        state = .loading
        let text = paragraphs[index]
        let settings = settingsProvider.snapshot()
        let synthesizer = self.synthesizer
        log.info("Synthesizing paragraph \(self.index + 1, privacy: .public)/\(self.paragraphs.count, privacy: .public)")

        speakTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let data = try await synthesizer.synthesize(text: text, settings: settings)
                guard !Task.isCancelled else {
                    return
                }
                await self.play(data: data, token: token)
            } catch is CancellationError {
                return
            } catch {
                await self.fail(error.localizedDescription, token: token)
            }
        }
    }

    private func play(data: Data, token: UUID) {
        guard generation == token else {
            return
        }
        do {
            try player.play(data: data) { [weak self] finished in
                Task { @MainActor in
                    self?.audioDidFinish(successfully: finished, token: token)
                }
            }
            state = .playing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func fail(_ message: String, token: UUID) {
        guard generation == token else {
            return
        }
        log.error("TTS failed: \(message, privacy: .public)")
        state = .failed(message)
    }

    private func audioDidFinish(successfully finished: Bool, token: UUID) {
        guard generation == token, finished else {
            return
        }
        switch state {
        case .playing:
            if index + 1 < paragraphs.count {
                index += 1
                speakCurrent()
            } else {
                stop()
            }
        case .idle, .loading, .paused, .failed:
            break
        }
    }

    private func cancelWork() {
        transientErrorTask?.cancel()
        transientErrorTask = nil
        speakTask?.cancel()
        speakTask = nil
        generation = UUID()
    }

    private func presentTransientError(_ message: String) {
        cancelWork()
        player.stop()
        paragraphs = []
        index = 0
        state = .failed(message)
        transientErrorTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                guard let self else {
                    return
                }
                if case .failed(let current) = self.state, current == message {
                    self.state = .idle
                }
            }
        }
    }
}
