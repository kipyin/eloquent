import Foundation
@testable import Eloquent

func makeSnapshot(
    engine: Engine = .openai,
    endpoint: String = "https://api.example.com/v1",
    apiKey: String = "",
    model: String = "tts-1",
    voice: String = "alloy",
    speed: Double = 1.1,
    paragraphSplit: ParagraphSplitMode = .blankLinesThenNewlines,
    speedApply: SpeedApplyMode = .nextParagraph
) -> SettingsSnapshot {
    SettingsSnapshot(
        engine: engine,
        endpoint: endpoint,
        apiKey: apiKey,
        model: model,
        voice: voice,
        speed: speed,
        paragraphSplit: paragraphSplit,
        speedApply: speedApply
    )
}

final class MemoryAPIKeyStore: APIKeyStoring {
    var value = ""

    func loadAPIKey() -> String {
        value
    }

    func saveAPIKey(_ secret: String) {
        value = secret
    }
}

struct StubClipboard: ClipboardReading {
    var text: String?

    func string() -> String? {
        text
    }
}

struct StubSelection: SelectionReading {
    var text: String?

    func selectedText() -> String? {
        text
    }
}

@MainActor
final class StubSettings: SettingsProviding {
    var value: SettingsSnapshot

    init(_ value: SettingsSnapshot) {
        self.value = value
    }

    func snapshot() -> SettingsSnapshot {
        value
    }
}

final class FakeSynthesizer: TTSSynthesizing, @unchecked Sendable {
    var texts: [String] = []
    var speeds: [Double] = []
    var result: Result<Data, Error> = .success(Data([0xFF, 0xFB, 0x90]))

    func synthesize(text: String, settings: SettingsSnapshot) async throws -> Data {
        texts.append(text)
        speeds.append(settings.speed)
        return try result.get()
    }
}

final class FakePlayer: AudioPlaying {
    private(set) var playCount = 0
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var stopCount = 0
    private(set) var lastData: Data?
    private var completion: ((Bool) -> Void)?

    func play(data: Data, completion: @escaping (Bool) -> Void) throws {
        lastData = data
        playCount += 1
        self.completion = completion
    }

    func pause() {
        pauseCount += 1
    }

    func resume() {
        resumeCount += 1
    }

    func stop() {
        stopCount += 1
        let finish = completion
        completion = nil
        finish?(false)
    }

    func finishSuccessfully() {
        let finish = completion
        completion = nil
        finish?(true)
    }
}

final class FakeHTTPTransport: HTTPPerforming, @unchecked Sendable {
    var lastRequest: URLRequest?
    var handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.example.com/v1/audio/speech")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (Data([0xFF, 0xFB]), response)
    }) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return try await handler(request)
    }
}

func httpResponse(
    for request: URLRequest,
    status: Int,
    body: Data
) -> (Data, URLResponse) {
    let response = HTTPURLResponse(
        url: request.url ?? URL(string: "https://api.example.com/v1/audio/speech")!,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: nil
    )!
    return (body, response)
}
