//
//  AudioRecorderService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import AVFoundation
import Foundation

@Observable
@MainActor
final class AudioRecorderService: NSObject {
    enum State: Equatable {
        case idle
        case recording
        case recorded(URL)
        case playing
        case paused
    }

    var state: State = .idle
    var recordingDuration: TimeInterval = 0
    var playbackProgress: Double = 0
    var playbackDuration: TimeInterval = 0
    var playbackRate: Float = 1.0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var timer: Timer?

    override init() {
        super.init()
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var hasRecording: Bool {
        if case .recorded = state { return true }
        return false
    }

    var isPlaying: Bool {
        if case .playing = state { return true }
        return false
    }

    var currentRecordingURL: URL? {
        if case .recorded(let url) = state {
            return url
        }
        return recordingURL
    }

    // MARK: - Recording

    func startRecording() async -> Bool {
        let permission = await requestMicrophonePermission()
        guard permission else { return false }

        do {
            try configureAudioSession(forRecording: true)

            let url = generateRecordingURL()
            recordingURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            state = .recording
            recordingDuration = 0
            startRecordingTimer()

            return true
        } catch {
            #if DEBUG
            print("❌ AudioRecorderService: Failed to start recording: \(error)")
            #endif
            return false
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        stopTimer()

        if let url = recordingURL {
            state = .recorded(url)
        } else {
            state = .idle
        }

        try? configureAudioSession(forRecording: false)
    }

    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        stopTimer()

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        recordingDuration = 0
        state = .idle

        try? configureAudioSession(forRecording: false)
    }

    // MARK: - Playback

    func play(url: URL? = nil) {
        let urlToPlay: URL
        if let url {
            urlToPlay = url
        } else if case .recorded(let recordedURL) = state {
            urlToPlay = recordedURL
        } else {
            return
        }

        do {
            try configureAudioSession(forRecording: false)

            audioPlayer = try AVAudioPlayer(contentsOf: urlToPlay)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.play()

            playbackDuration = audioPlayer?.duration ?? 0
            state = .playing
            startPlaybackTimer()
        } catch {
            #if DEBUG
            print("❌ AudioRecorderService: Failed to play audio: \(error)")
            #endif
        }
    }

    func pause() {
        audioPlayer?.pause()
        stopTimer()
        state = .paused
    }

    func resume() {
        audioPlayer?.play()
        state = .playing
        startPlaybackTimer()
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopTimer()
        playbackProgress = 0

        if let url = recordingURL {
            state = .recorded(url)
        } else {
            state = .idle
        }
    }

    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        player.currentTime = progress * player.duration
        playbackProgress = progress
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        audioPlayer?.rate = rate
    }

    // MARK: - Cleanup

    func deleteRecording() {
        stopPlayback()

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        recordingDuration = 0
        playbackDuration = 0
        playbackProgress = 0
        state = .idle
    }

    func reset() {
        cancelRecording()
        stopPlayback()
        recordingURL = nil
        recordingDuration = 0
        playbackDuration = 0
        playbackProgress = 0
        state = .idle
    }

    func loadExistingRecording(from url: URL) {
        recordingURL = url
        state = .recorded(url)

        if let player = try? AVAudioPlayer(contentsOf: url) {
            playbackDuration = player.duration
            recordingDuration = player.duration
        }
    }

    // MARK: - Private Helpers

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession(forRecording: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        if forRecording {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        } else {
            try session.setCategory(.playback, mode: .default)
        }
        try session.setActive(true)
    }

    private func generateRecordingURL() -> URL {
        let filename = "voice_\(UUID().uuidString).m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func startRecordingTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0
            }
        }
    }

    private func startPlaybackTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let player = self.audioPlayer, self.isPlaying else { return }
                self.playbackProgress = player.currentTime / player.duration
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                cancelRecording()
            }
        }
    }
}

extension AudioRecorderService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopPlayback()
        }
    }
}
