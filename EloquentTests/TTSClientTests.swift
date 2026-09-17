import XCTest
@testable import Eloquent

final class TTSClientTests: XCTestCase {
    func testEmptyInputThrowsBeforeTransport() async {
        let transport = FakeHTTPTransport { _ in
            XCTFail("Transport should not run")
            throw TTSError.invalidResponse
        }
        let client = TTSClient(transport: transport)

        do {
            _ = try await client.synthesize(text: "  ", settings: makeSnapshot())
            XCTFail("Expected emptyInput")
        } catch {
            XCTAssertEqual(error as? TTSError, .emptyInput)
        }
        XCTAssertNil(transport.lastRequest)
    }

    func testEmptyEndpointThrowsBeforeTransport() async {
        let transport = FakeHTTPTransport { _ in
            XCTFail("Transport should not run")
            throw TTSError.invalidResponse
        }
        let client = TTSClient(transport: transport)

        do {
            _ = try await client.synthesize(text: "Hello", settings: makeSnapshot(endpoint: ""))
            XCTFail("Expected missingEndpoint")
        } catch {
            XCTAssertEqual(error as? TTSError, .missingEndpoint)
        }
        XCTAssertNil(transport.lastRequest)
    }

    func testSlashOnlyEndpointIsInvalid() async {
        let client = TTSClient(transport: FakeHTTPTransport())

        do {
            _ = try await client.synthesize(text: "Hello", settings: makeSnapshot(endpoint: "///"))
            XCTFail("Expected invalidEndpoint")
        } catch {
            XCTAssertEqual(error as? TTSError, .invalidEndpoint("///"))
        }
    }

    func testSpeechURLStripsTrailingSlashAndAppendsAudioSpeech() async throws {
        let transport = FakeHTTPTransport()
        let client = TTSClient(transport: transport)

        _ = try await client.synthesize(
            text: "Hello",
            settings: makeSnapshot(endpoint: "https://api.example.com/v1/")
        )

        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://api.example.com/v1/audio/speech")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
    }

    func testBodyOmitsEngineAndLanguageAndUsesPublicDefaults() async throws {
        let transport = FakeHTTPTransport()
        let client = TTSClient(transport: transport)
        let settings = makeSnapshot(
            engine: "openai",
            apiKey: "",
            model: "",
            voice: "",
            speed: 1.55
        )

        _ = try await client.synthesize(text: "  Hello  ", settings: settings)

        let body = try XCTUnwrap(transport.lastRequest?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "tts-1")
        XCTAssertEqual(json["voice"] as? String, "alloy")
        XCTAssertEqual(json["input"] as? String, "Hello")
        let speed = json["speed"] as? Double ?? (json["speed"] as? NSNumber)?.doubleValue
        XCTAssertEqual(speed, 1.5)
        XCTAssertEqual(json["response_format"] as? String, "mp3")
        XCTAssertNil(json["engine"])
        XCTAssertNil(json["language"])
        XCTAssertNil(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testBearerTokenOnlyWhenAPIKeyIsSet() async throws {
        let transport = FakeHTTPTransport()
        let client = TTSClient(transport: transport)

        _ = try await client.synthesize(
            text: "Hello",
            settings: makeSnapshot(apiKey: "sk-test")
        )

        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
    }

    func testHTTPErrorUsesProviderMessage() async {
        let transport = FakeHTTPTransport { request in
            let body = Data("{\"error\":{\"message\":\"rate limited\"}}".utf8)
            return httpResponse(for: request, status: 429, body: body)
        }
        let client = TTSClient(transport: transport)

        do {
            _ = try await client.synthesize(text: "Hello", settings: makeSnapshot())
            XCTFail("Expected HTTP error")
        } catch {
            XCTAssertEqual(error as? TTSError, .http(429, "rate limited"))
        }
    }

    func testJSONPayloadAt200IsAnError() async {
        let transport = FakeHTTPTransport { request in
            httpResponse(for: request, status: 200, body: Data("{\"message\":\"oops\"}".utf8))
        }
        let client = TTSClient(transport: transport)

        do {
            _ = try await client.synthesize(text: "Hello", settings: makeSnapshot())
            XCTFail("Expected JSON payload error")
        } catch {
            XCTAssertEqual(error as? TTSError, .http(200, "oops"))
        }
    }

    func testEmptyAudioThrows() async {
        let transport = FakeHTTPTransport { request in
            httpResponse(for: request, status: 200, body: Data())
        }
        let client = TTSClient(transport: transport)

        do {
            _ = try await client.synthesize(text: "Hello", settings: makeSnapshot())
            XCTFail("Expected emptyAudio")
        } catch {
            XCTAssertEqual(error as? TTSError, .emptyAudio)
        }
    }
}
