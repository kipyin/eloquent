import Foundation

protocol HTTPPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPPerforming {}

protocol TTSSynthesizing: Sendable {
    func synthesize(text: String, settings: SettingsSnapshot) async throws -> Data
}

struct TTSClient: TTSSynthesizing {
    private static let timeout: TimeInterval = 180

    private let transport: any HTTPPerforming

    init(transport: any HTTPPerforming = URLSession.shared) {
        self.transport = transport
    }

    func synthesize(text: String, settings: SettingsSnapshot) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TTSError.emptyInput
        }
        let endpoint = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else {
            throw TTSError.missingEndpoint
        }
        guard let url = Self.speechURL(from: endpoint, engine: settings.engine) else {
            throw TTSError.invalidEndpoint(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try Self.encodeBody(text: trimmed, settings: settings)

        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TTSError.http(http.statusCode, errorMessage(from: data))
        }
        if data.isEmpty {
            throw TTSError.emptyAudio
        }
        if looksLikeJSON(data) {
            throw TTSError.http(http.statusCode, errorMessage(from: data))
        }
        return data
    }

    private static func speechURL(from endpoint: String, engine: Engine) -> URL? {
        let base = Engine.normalizedEndpoint(endpoint)
        guard !base.isEmpty else {
            return nil
        }
        return URL(string: base + engine.speechPath)
    }

    private static func encodeBody(text: String, settings: SettingsSnapshot) throws -> Data {
        let voice = settings.voice.isEmpty ? settings.engine.defaultVoice : settings.voice
        switch settings.engine {
        case .openai:
            let body = SpeechRequestBody(
                model: settings.model.isEmpty ? TTSDefaults.model : settings.model,
                voice: voice,
                input: text,
                speed: TTSDefaults.clampSpeed(settings.speed),
                response_format: "mp3"
            )
            return try JSONEncoder().encode(body)
        case .grok:
            let body = GrokSpeechRequestBody(
                text: text,
                voice_id: voice,
                language: "auto",
                speed: TTSDefaults.clampSpeed(settings.speed)
            )
            return try JSONEncoder().encode(body)
        }
    }

    private func looksLikeJSON(_ data: Data) -> Bool {
        guard let first = data.first else {
            return false
        }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    private func errorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "TTS request failed." : raw
    }
}

private struct SpeechRequestBody: Encodable {
    let model: String
    let voice: String
    let input: String
    let speed: Double
    let response_format: String
}

private struct GrokSpeechRequestBody: Encodable {
    let text: String
    let voice_id: String
    let language: String
    let speed: Double
}

enum TTSError: LocalizedError, Equatable {
    case emptyInput
    case missingEndpoint
    case invalidEndpoint(String)
    case invalidResponse
    case emptyAudio
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Nothing to speak."
        case .missingEndpoint:
            return "Set Endpoint in Settings. Eloquent needs a /v1 base URL."
        case .invalidEndpoint(let endpoint):
            return "Invalid endpoint: \(endpoint)"
        case .invalidResponse:
            return "The TTS server returned an invalid response."
        case .emptyAudio:
            return "The TTS server returned no audio."
        case .http(let code, let message):
            return "TTS HTTP \(code): \(message)"
        }
    }
}
