//
//  ClientJournalSection.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import SwiftUI

struct ClientJournalSection: View {
    let clientId: String
    let clientName: String

    @State private var journalRepo = JournalRepository()
    @State private var selectedEntryId: String?

    private var selectedEntry: JournalEntry? {
        guard let selectedEntryId else { return nil }
        return journalRepo.entry(byId: selectedEntryId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader

            if journalRepo.entries.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
        .onAppear {
            #if DEBUG
            print("🔍 ClientJournalSection: Starting listener for clientId: \(clientId)")
            #endif
            journalRepo.startListeningToSharedEntries(forClientId: clientId)
        }
        .onDisappear {
            journalRepo.stopListening()
        }
        .sheet(isPresented: Binding(
            get: { selectedEntryId != nil },
            set: { if !$0 { selectedEntryId = nil } }
        )) {
            if let entry = selectedEntry {
                JournalEntryDetailSheet(entry: entry, clientName: clientName)
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Label("Щоденник", systemImage: "book.closed")
                .font(.headline)
                .foregroundStyle(Color.psyspaceTextPrimary)

            Spacer()

            Text("\(journalRepo.entries.count) записів")
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundStyle(Color.psyspaceTextSecondary.opacity(0.5))

            Text("Немає спільних записів")
                .font(.subheadline)
                .foregroundStyle(Color.psyspaceTextSecondary)

            Text("Клієнт ще не поділився записами з щоденника")
                .font(.caption)
                .foregroundStyle(Color.psyspaceTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    private var entriesList: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(journalRepo.entries) { entry in
                TherapistJournalEntryCard(entry: entry) {
                    selectedEntryId = entry.entryId
                }
            }
        }
    }
}

private struct TherapistJournalEntryCard: View {
    let entry: JournalEntry
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                if let mood = entry.mood {
                    Text(mood.emoji)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if !entry.title.isEmpty {
                        Text(entry.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.psyspaceTextPrimary)
                            .lineLimit(1)
                    }

                    Text(entry.preview)
                        .font(.caption)
                        .foregroundStyle(Color.psyspaceTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        if entry.hasAudio {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundStyle(Color.psyspaceSecondary)
                        }

                        Text(entry.createdAtFormatted)
                            .font(.caption2)
                            .foregroundStyle(Color.psyspaceTextSecondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.psyspaceTextSecondary.opacity(0.5))
                }
            }
            .padding(Spacing.sm)
            .background(Color.psyspaceCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

private struct JournalEntryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let entry: JournalEntry
    let clientName: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if entry.hasAudio, let urlString = entry.audioURL, let url = URL(string: urlString) {
                        voiceSection(url: url, duration: entry.audioDuration)
                    }

                    if !entry.plainTextContent.isEmpty {
                        content
                    }

                    if let mood = entry.mood {
                        moodSection(mood: mood)
                    }
                }
                .padding()
            }
            .background(Color.psyspaceBackground)
            .navigationTitle("Запис клієнта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(clientName)
                    .font(.subheadline)
                    .foregroundStyle(Color.psyspaceTextSecondary)

                Spacer()

                Text(entry.createdAtFormatted)
                    .font(.caption)
                    .foregroundStyle(Color.psyspaceTextSecondary)
            }

            if !entry.title.isEmpty {
                Text(entry.title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.psyspaceTextPrimary)
            }
        }
    }

    private var content: some View {
        Text(entry.plainTextContent)
            .font(.body)
            .foregroundStyle(Color.psyspaceTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func voiceSection(url: URL, duration: TimeInterval?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Голосове повідомлення")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.psyspaceTextSecondary)

            VoicePlayerView(audioURL: url, knownDuration: duration)
        }
    }

    private func moodSection(mood: Mood) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider()

            HStack(spacing: Spacing.sm) {
                Text(mood.emoji)
                    .font(.title2)

                Text(mood.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.psyspaceTextPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.psyspaceCardBackground)
            .clipShape(.rect(cornerRadius: CornerRadius.md))
        }
    }
}

#Preview {
    ClientJournalSection(clientId: "test-client", clientName: "Іван Петренко")
        .padding()
        .background(Color.psyspaceBackground)
}
