//
//  VoiceRecorderView.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct VoiceRecorderView: View {
    @Bindable var recorder: AudioRecorderService
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            switch recorder.state {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .recorded:
                recordedView
            case .playing, .paused:
                playbackView
            }
        }
        .padding()
        .background(Color.psyspaceCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }

    private var idleView: some View {
        VStack(spacing: Spacing.sm) {
            Text("Голосове повідомлення")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.psyspaceTextSecondary)

            Button {
                Task { await recorder.startRecording() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                    Text("Записати")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.psyspaceSecondary)
                .clipShape(.rect(cornerRadius: CornerRadius.md))
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(Color.psyspaceError)
                    .frame(width: 12, height: 12)
                    .modifier(PulseAnimation())

                Text("Запис...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Spacer()

                Text(formatDuration(recorder.recordingDuration))
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(Color.psyspaceTextPrimary)
            }

            HStack(spacing: Spacing.md) {
                Button {
                    recorder.cancelRecording()
                } label: {
                    Text("Скасувати")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.psyspaceTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.psyspaceBackground)
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                Button {
                    recorder.stopRecording()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "stop.fill")
                        Text("Зупинити")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.psyspaceError)
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }
            }
        }
    }

    private var recordedView: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundStyle(Color.psyspaceSecondary)

                Text("Голосове повідомлення")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)

                Spacer()

                Text(formatDuration(recorder.recordingDuration))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            HStack(spacing: Spacing.md) {
                Button {
                    recorder.deleteRecording()
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.psyspaceError)
                        .frame(width: 44, height: 36)
                        .background(Color.psyspaceError.opacity(0.1))
                        .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }

                Button {
                    recorder.play()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "play.fill")
                        Text("Прослухати")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.psyspaceSecondary)
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
                }
            }
        }
    }

    private var playbackView: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Button {
                    if recorder.isPlaying {
                        recorder.pause()
                    } else {
                        recorder.resume()
                    }
                } label: {
                    Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Color.psyspaceSecondary)
                        .frame(width: 44, height: 44)
                        .background(Color.psyspaceSecondary.opacity(0.1))
                        .clipShape(Circle())
                }

                VStack(spacing: Spacing.xxs) {
                    ProgressView(value: recorder.playbackProgress)
                        .tint(Color.psyspaceSecondary)

                    HStack {
                        Text(formatDuration(recorder.playbackProgress * recorder.playbackDuration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.psyspaceTextSecondary)

                        Spacer()

                        Text(formatDuration(recorder.playbackDuration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.psyspaceTextSecondary)
                    }
                }
            }

            Button {
                recorder.stopPlayback()
            } label: {
                Text("Готово")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceSecondary)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        VoiceRecorderView(recorder: AudioRecorderService())
    }
    .padding()
    .background(Color.psyspaceBackground)
}
