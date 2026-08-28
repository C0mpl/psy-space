//
//  VoicePlayerView.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct VoicePlayerView: View {
    let audioURL: URL
    var knownDuration: TimeInterval?

    @State private var player = AudioRecorderService()
    @State private var localURL: URL?
    @State private var isDownloading = false
    @State private var downloadError: Error?
    @State private var isSeeking = false

    private static let playbackRates: [Float] = [1.0, 1.5, 2.0]

    private var isRemoteURL: Bool {
        audioURL.scheme == "https" || audioURL.scheme == "http"
    }

    private var displayDuration: TimeInterval {
        if player.playbackDuration > 0 {
            return player.playbackDuration
        }
        return knownDuration ?? 0
    }

    private var currentRateLabel: String {
        if player.playbackRate == 1.0 {
            return "1x"
        } else if player.playbackRate == 1.5 {
            return "1.5x"
        } else {
            return "2x"
        }
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                playButton

                Slider(
                    value: Binding(
                        get: { player.playbackProgress },
                        set: { newValue in
                            isSeeking = true
                            player.seek(to: newValue)
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing {
                            isSeeking = false
                        }
                    }
                )
                .tint(Color.seansSecondary)

                speedButton
            }

            HStack {
                Text(formatDuration(player.playbackProgress * displayDuration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.seansTextSecondary)

                Spacer()

                Text(formatDuration(displayDuration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.seansTextSecondary)
            }
        }
        .padding(Spacing.sm)
        .background(Color.seansSecondary.opacity(0.05))
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
        .onAppear {
            if !isRemoteURL {
                player.loadExistingRecording(from: audioURL)
            }
        }
        .onDisappear {
            player.stopPlayback()
        }
    }

    private var playButton: some View {
        Button(player.isPlaying ? "Пауза" : "Відтворити", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
            handlePlayPause()
        }
        .labelStyle(.iconOnly)
        .font(.body)
        .foregroundStyle(Color.seansSecondary)
        .frame(width: 40, height: 40)
        .background(Color.seansSecondary.opacity(0.1))
        .clipShape(Circle())
        .disabled(isDownloading)
        .overlay {
            if isDownloading {
                ProgressView()
                    .frame(width: 40, height: 40)
                    .background(Color.seansSecondary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private var speedButton: some View {
        Button {
            cyclePlaybackRate()
        } label: {
            Text(currentRateLabel)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(player.playbackRate == 1.0 ? Color.seansTextSecondary : Color.seansSecondary)
                .frame(width: 36, height: 28)
                .background(Color.seansSecondary.opacity(player.playbackRate == 1.0 ? 0.05 : 0.15))
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
        .accessibilityLabel("Швидкість відтворення")
        .accessibilityValue(currentRateLabel)
    }

    private func handlePlayPause() {
        if player.isPlaying {
            player.pause()
        } else if case .paused = player.state {
            player.resume()
        } else if let local = localURL {
            player.play(url: local)
        } else if isRemoteURL {
            downloadAndPlay()
        } else {
            player.play(url: audioURL)
        }
    }

    private func cyclePlaybackRate() {
        guard let currentIndex = Self.playbackRates.firstIndex(of: player.playbackRate) else {
            player.setPlaybackRate(1.0)
            return
        }
        let nextIndex = (currentIndex + 1) % Self.playbackRates.count
        player.setPlaybackRate(Self.playbackRates[nextIndex])
    }

    private func downloadAndPlay() {
        isDownloading = true
        downloadError = nil

        Task {
            do {
                let downloaded = try await StorageService.shared.downloadJournalAudio(
                    from: audioURL.absoluteString
                )
                localURL = downloaded
                player.loadExistingRecording(from: downloaded)
                player.play(url: downloaded)
            } catch {
                #if DEBUG
                print("❌ VoicePlayerView: Failed to download audio: \(error)")
                #endif
                downloadError = error
            }
            isDownloading = false
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VoicePlayerCompactView: View {
    let duration: TimeInterval

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundStyle(Color.seansSecondary)

            Text(formatDuration(duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.seansTextSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.seansSecondary.opacity(0.1))
        .clipShape(.rect(cornerRadius: CornerRadius.sm))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        VoicePlayerCompactView(duration: 45)
        VoicePlayerCompactView(duration: 125)
    }
    .padding()
    .background(Color.seansBackground)
}
