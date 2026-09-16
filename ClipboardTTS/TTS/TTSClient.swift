import Foundation

enum TTSClient {
    private static let timeout: TimeInterval = 180

    static func synthesize(text: String, settings: SettingsSnapshot) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TTSError.emptyInput
        }
        guard let url = speechURL(from: settings.endpoint) else {
            throw TTSError.invalidEndpoint(settings.endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Engine is stored for Moshi-style settings parity and is not sent in the body.
        // Language is omitted so the local proxy can apply its zh/en heuristic.
        // Never send ja or auto. If a language field is added later, it may only be zh or en.
        let body = SpeechRequestBody(
            model: settings.model.isEmpty ? TTSDefaults.model : settings.model,
            voice: settings.voice.isEmpty ? TTSDefaults.voice : settings.voice,
            input: trimmed,
            speed: TTSDefaults.clampSpeed(settings.speed),
            response_format: "mp3"
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
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

    static func speechURL(from endpoint: String) -> URL? {
        var base = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        guard !base.isEmpty else {
            return nil
        }
        return URL(string: base + "/audio/speech")
    }

    private static func looksLikeJSON(_ data: Data) -> Bool {
        guard let first = data.first else {
            return false
        }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    private static func errorMessage(from data: Data) -> String {
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

enum TTSError: LocalizedError, Equatable {
    case emptyInput
    case invalidEndpoint(String)
    case invalidResponse
    case emptyAudio
    case playbackFailed
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Nothing to speak."
        case .invalidEndpoint(let endpoint):
            return "Invalid endpoint: \(endpoint)"
        case .invalidResponse:
            return "The TTS server returned an invalid response."
        case .emptyAudio:
            return "The TTS server returned no audio."
        case .playbackFailed:
            return "Audio playback failed."
        case .http(let code, let message):
            return "TTS HTTP \(code): \(message)"
        }
    }
}
