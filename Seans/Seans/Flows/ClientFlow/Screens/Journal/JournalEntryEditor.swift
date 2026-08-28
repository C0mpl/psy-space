//
//  JournalEntryEditor.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import SwiftUI

struct JournalEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JournalRepository.self) private var journalRepo
    @Environment(JournalPreferences.self) private var preferences

    let clientId: String
    var existingEntry: JournalEntry?

    @State private var title = ""
    @State private var richTextState = RichTextState()
    @State private var mood: Mood?
    @State private var isShared = false
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var audioRecorder = AudioRecorderService()
    @State private var existingAudioURL: String?

    private var isEditing: Bool { existingEntry != nil }

    private var canSave: Bool {
        let hasText = !richTextState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAudio = audioRecorder.hasRecording || existingAudioURL != nil
        return !isSaving && (hasText || hasAudio)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    titleSection
                    contentSection
                    voiceSection
                    moodSection
                    sharingSection
                }
                .padding()
            }
            .background(Color.seansBackground)
            .navigationTitle(isEditing ? "Редагувати" : "Новий запис")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }

                if isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.seansError)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Видалити запис?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Видалити", role: .destructive) {
                    Task { await deleteEntry() }
                }
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Цю дію неможливо скасувати.")
            }
            .overlay {
                if isSaving {
                    SeansLoadingOverlay(message: "Зберігаємо...")
                }
            }
        }
        .onAppear {
            loadExistingEntry()
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Заголовок")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextSecondary)

            TextField("Необов'язково", text: $title)
                .font(.headline)
                .padding(Spacing.sm)
                .background(Color.seansCardBackground)
                .clipShape(.rect(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.seansTextSecondary.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Запис")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextSecondary)

            RichTextEditor(
                state: richTextState,
                placeholder: "Що у вас на думці?",
                minHeight: 200
            )
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Голосове повідомлення")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.seansTextSecondary)

            if let existingURL = existingAudioURL, !audioRecorder.hasRecording {
                existingAudioView(url: existingURL)
            } else {
                VoiceRecorderView(recorder: audioRecorder) {
                    existingAudioURL = nil
                }
            }
        }
    }

    private func existingAudioView(url: String) -> some View {
        HStack(spacing: Spacing.md) {
            if let audioURL = URL(string: url) {
                VoicePlayerView(audioURL: audioURL, knownDuration: existingEntry?.audioDuration)
            }

            Button {
                existingAudioURL = nil
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(Color.seansError)
                    .frame(width: 44, height: 36)
                    .background(Color.seansError.opacity(0.1))
                    .clipShape(.rect(cornerRadius: CornerRadius.sm))
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            MoodPicker(selectedMood: $mood)
        }
        .padding()
        .background(Color.seansCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }

    private var sharingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $isShared) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.2")
                        .foregroundStyle(isShared ? Color.seansSecondary : Color.seansTextSecondary)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Поділитися з терапевтом")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.seansTextPrimary)

                        Text("Ваш терапевт зможе переглянути цей запис")
                            .font(.caption)
                            .foregroundStyle(Color.seansTextSecondary)
                    }
                }
            }
            .tint(Color.seansSecondary)
        }
        .padding()
        .background(Color.seansCardBackground)
        .clipShape(.rect(cornerRadius: CornerRadius.md))
    }

    private func loadExistingEntry() {
        guard let entry = existingEntry else {
            isShared = preferences.defaultShareWithTherapist
            return
        }

        title = entry.title
        richTextState.load(serialized: entry.content)
        mood = entry.mood
        isShared = entry.isShared
        existingAudioURL = entry.audioURL
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let plainText = richTextState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAudio = audioRecorder.hasRecording || existingAudioURL != nil

        // Must have either text or audio
        guard !plainText.isEmpty || hasAudio else { return }

        let content = richTextState.serialized
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Determine audio to save
        let audioLocalURL = audioRecorder.currentRecordingURL
        let audioDuration = audioRecorder.hasRecording ? audioRecorder.recordingDuration : nil

        do {
            if var entry = existingEntry {
                entry.title = trimmedTitle
                entry.content = content
                entry.plainTextContent = plainText
                entry.mood = mood
                entry.isShared = isShared

                // Handle audio changes
                if audioRecorder.hasRecording {
                    // New recording - upload it
                    if let localURL = audioLocalURL {
                        let remoteURL = try await StorageService.shared.uploadJournalAudio(
                            clientId: clientId,
                            entryId: entry.entryId,
                            localURL: localURL
                        )
                        entry.audioURL = remoteURL
                        entry.audioDuration = audioDuration
                    }
                } else if existingAudioURL == nil && entry.audioURL != nil {
                    // Audio was deleted
                    entry.audioURL = nil
                    entry.audioDuration = nil
                }

                try await journalRepo.updateEntry(entry)
            } else {
                #if DEBUG
                print("📝 JournalEntryEditor: Creating entry with clientId: \(clientId), isShared: \(isShared)")
                #endif
                try await journalRepo.createEntry(
                    clientId: clientId,
                    title: trimmedTitle,
                    content: content,
                    plainTextContent: plainText,
                    mood: mood,
                    isShared: isShared,
                    audioLocalURL: audioLocalURL,
                    audioDuration: audioDuration
                )
            }

            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("❌ JournalEntryEditor: Failed to save entry: \(error)")
            #endif
        }
    }

    private func deleteEntry() async {
        guard let entry = existingEntry else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await journalRepo.deleteEntry(entry.entryId)
            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("❌ JournalEntryEditor: Failed to delete entry: \(error)")
            #endif
        }
    }
}

#Preview {
    JournalEntryEditor(clientId: "test-client")
        .environment(JournalRepository())
        .environment(JournalPreferences())
}
