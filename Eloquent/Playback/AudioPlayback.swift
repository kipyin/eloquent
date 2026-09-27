import AVFoundation
import Foundation

protocol AudioPlaying: AnyObject {
    func play(data: Data, completion: @escaping (Bool) -> Void) throws
    func pause()
    func resume()
    func stop()
}

enum AudioPlaybackError: LocalizedError {
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Audio playback failed."
        }
    }
}

final class AudioPlayback: NSObject, AVAudioPlayerDelegate, AudioPlaying {
    private var player: AVAudioPlayer?
    private var completion: ((Bool) -> Void)?
    private var tempURL: URL?

    func play(data: Data, completion: @escaping (Bool) -> Void) throws {
        stop()
        self.completion = completion

        do {
            let audioPlayer: AVAudioPlayer
            if let fromData = try? AVAudioPlayer(data: data) {
                audioPlayer = fromData
            } else {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("eloquent-\(UUID().uuidString).mp3")
                try data.write(to: url, options: .atomic)
                tempURL = url
                audioPlayer = try AVAudioPlayer(contentsOf: url)
            }

            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            player = audioPlayer
            guard audioPlayer.play() else {
                throw AudioPlaybackError.playbackFailed
            }
        } catch {
            self.completion = nil
            cleanupTempFile()
            throw error
        }
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        endPlayback(success: false, haltPlayer: true)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.finish(success: flag)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.finish(success: false)
        }
    }

    private func finish(success: Bool) {
        endPlayback(success: success, haltPlayer: false)
    }

    // Clear the callback before halting so player.stop() cannot also finish.
    private func endPlayback(success: Bool, haltPlayer: Bool) {
        let callback = completion
        completion = nil
        if haltPlayer {
            player?.delegate = nil
            player?.stop()
        }
        player = nil
        cleanupTempFile()
        callback?(success)
    }

    private func cleanupTempFile() {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
            self.tempURL = nil
        }
    }
}
