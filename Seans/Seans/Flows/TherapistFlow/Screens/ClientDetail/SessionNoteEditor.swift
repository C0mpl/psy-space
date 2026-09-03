//
//  SessionNoteEditor.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import SwiftUI

struct SessionNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionNoteRepository.self) private var noteRepo

    let bookingId: String
    let clientId: String
    let sessionDate: Date
    var existingNote: SessionNote?

    @State private var selectedSection: NoteSection = .hypotheses
    @State private var hypothesesState = RichTextState()
    @State private var observationsState = RichTextState()
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    private var isEditing: Bool { existingNote != nil }

    private var canSave: Bool {
        let hasHypotheses = !hypothesesState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasObservations = !observationsState.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !isSaving && (hasHypotheses || hasObservations)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sessionHeader
                sectionPicker
                editorContent
            }
            .background(Color.seansBackground)
            .navigationTitle(isEditing ? "Редагувати нотатку" : "Нова нотатка")
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
                "Видалити нотатку?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Видалити", role: .destructive) {
                    Task { await deleteNote() }
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
            loadExistingNote()
        }
    }

    private var sessionHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "calendar")
                .font(.subheadline)
                .foregroundStyle(Color.seansSecondary)

            Text("Сеанс: \(sessionDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(Color.seansTextSecondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(Color.seansCardBackground)
    }

    private var sectionPicker: some View {
        Picker("Розділ", selection: $selectedSection) {
            ForEach(NoteSection.allCases, id: \.self) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    @ViewBuilder
    private var editorContent: some View {
        switch selectedSection {
        case .hypotheses:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Гіпотези та спостереження щодо клієнта")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
                    .padding(.horizontal)

                RichTextEditor(
                    state: hypothesesState,
                    placeholder: "Ваші гіпотези про стан клієнта, можливі причини проблем, динаміку...",
                    minHeight: 300
                )
                .padding(.horizontal)
            }

        case .observations:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Спостереження під час сеансу")
                    .font(.caption)
                    .foregroundStyle(Color.seansTextSecondary)
                    .padding(.horizontal)

                RichTextEditor(
                    state: observationsState,
                    placeholder: "Поведінка, емоційні реакції, невербальні сигнали, ключові моменти...",
                    minHeight: 300
                )
                .padding(.horizontal)
            }
        }

        Spacer()
    }

    private func loadExistingNote() {
        guard let note = existingNote else { return }

        hypothesesState.load(serialized: note.hypotheses)
        observationsState.load(serialized: note.observations)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let hypotheses = hypothesesState.serialized
        let observations = observationsState.serialized

        let plainHypotheses = hypothesesState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainObservations = observationsState.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainTextContent = [plainHypotheses, plainObservations]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        do {
            if var note = existingNote {
                note.hypotheses = hypotheses
                note.observations = observations
                note.plainTextContent = plainTextContent
                try await noteRepo.updateNote(note)
            } else {
                try await noteRepo.createNote(
                    bookingId: bookingId,
                    clientId: clientId,
                    hypotheses: hypotheses,
                    observations: observations,
                    plainTextContent: plainTextContent
                )
            }

            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("SessionNoteEditor: Failed to save note: \(error)")
            #endif
        }
    }

    private func deleteNote() async {
        guard let note = existingNote else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await noteRepo.deleteNote(note.noteId)
            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
            #if DEBUG
            print("SessionNoteEditor: Failed to delete note: \(error)")
            #endif
        }
    }
}

private enum NoteSection: CaseIterable {
    case hypotheses
    case observations

    var title: String {
        switch self {
        case .hypotheses: "Гіпотези"
        case .observations: "Спостереження"
        }
    }
}

#Preview {
    SessionNoteEditor(
        bookingId: "booking-1",
        clientId: "client-1",
        sessionDate: .now
    )
    .environment(SessionNoteRepository())
}
