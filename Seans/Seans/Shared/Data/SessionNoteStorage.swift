//
//  SessionNoteStorage.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import Foundation
import SwiftData

@Model
final class StoredSessionNote {
    @Attribute(.unique) var noteId: String
    var bookingId: String
    var clientId: String
    var hypotheses: String
    var observations: String
    var plainTextContent: String
    var createdAt: Date
    var updatedAt: Date

    init(
        noteId: String,
        bookingId: String,
        clientId: String,
        hypotheses: String,
        observations: String,
        plainTextContent: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.noteId = noteId
        self.bookingId = bookingId
        self.clientId = clientId
        self.hypotheses = hypotheses
        self.observations = observations
        self.plainTextContent = plainTextContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toSessionNote() -> SessionNote {
        SessionNote(
            id: noteId,
            bookingId: bookingId,
            clientId: clientId,
            hypotheses: hypotheses,
            observations: observations,
            plainTextContent: plainTextContent,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from note: SessionNote) {
        hypotheses = note.hypotheses
        observations = note.observations
        plainTextContent = note.plainTextContent
        updatedAt = note.updatedAt
    }
}

@Model
final class StoredClientAnamnesis {
    @Attribute(.unique) var clientId: String
    var background: String
    var presentingIssues: String
    var treatmentGoals: String
    var plainTextSummary: String
    var createdAt: Date
    var updatedAt: Date

    init(
        clientId: String,
        background: String,
        presentingIssues: String,
        treatmentGoals: String,
        plainTextSummary: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.clientId = clientId
        self.background = background
        self.presentingIssues = presentingIssues
        self.treatmentGoals = treatmentGoals
        self.plainTextSummary = plainTextSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toClientAnamnesis() -> ClientAnamnesis {
        ClientAnamnesis(
            id: clientId,
            clientId: clientId,
            background: background,
            presentingIssues: presentingIssues,
            treatmentGoals: treatmentGoals,
            plainTextSummary: plainTextSummary,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from anamnesis: ClientAnamnesis) {
        background = anamnesis.background
        presentingIssues = anamnesis.presentingIssues
        treatmentGoals = anamnesis.treatmentGoals
        plainTextSummary = anamnesis.plainTextSummary
        updatedAt = anamnesis.updatedAt
    }
}

@MainActor
final class SessionNoteStorage {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelContainer.mainContext }

    init() throws {
        let schema = Schema([StoredSessionNote.self, StoredClientAnamnesis.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Session Notes

    func loadNotes(forClientId clientId: String) -> [SessionNote] {
        let descriptor = FetchDescriptor<StoredSessionNote>(
            predicate: #Predicate { $0.clientId == clientId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let notes = try? modelContext.fetch(descriptor) else {
            return []
        }
        return notes.map { $0.toSessionNote() }
    }

    func loadNote(forBookingId bookingId: String) -> SessionNote? {
        let descriptor = FetchDescriptor<StoredSessionNote>(
            predicate: #Predicate { $0.bookingId == bookingId }
        )
        guard let stored = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return stored.toSessionNote()
    }

    func saveNote(_ note: SessionNote) {
        let noteId = note.noteId
        let descriptor = FetchDescriptor<StoredSessionNote>(
            predicate: #Predicate { $0.noteId == noteId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: note)
        } else {
            let stored = StoredSessionNote(
                noteId: note.noteId,
                bookingId: note.bookingId,
                clientId: note.clientId,
                hypotheses: note.hypotheses,
                observations: note.observations,
                plainTextContent: note.plainTextContent,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt
            )
            modelContext.insert(stored)
        }
        try? modelContext.save()
    }

    func saveNotes(_ notes: [SessionNote]) {
        for note in notes {
            saveNote(note)
        }
    }

    func deleteNote(_ noteId: String) {
        let descriptor = FetchDescriptor<StoredSessionNote>(
            predicate: #Predicate { $0.noteId == noteId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    // MARK: - Anamnesis

    func loadAnamnesis(forClientId clientId: String) -> ClientAnamnesis? {
        let descriptor = FetchDescriptor<StoredClientAnamnesis>(
            predicate: #Predicate { $0.clientId == clientId }
        )
        guard let stored = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return stored.toClientAnamnesis()
    }

    func saveAnamnesis(_ anamnesis: ClientAnamnesis) {
        let clientId = anamnesis.clientId
        let descriptor = FetchDescriptor<StoredClientAnamnesis>(
            predicate: #Predicate { $0.clientId == clientId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: anamnesis)
        } else {
            let stored = StoredClientAnamnesis(
                clientId: anamnesis.clientId,
                background: anamnesis.background,
                presentingIssues: anamnesis.presentingIssues,
                treatmentGoals: anamnesis.treatmentGoals,
                plainTextSummary: anamnesis.plainTextSummary,
                createdAt: anamnesis.createdAt,
                updatedAt: anamnesis.updatedAt
            )
            modelContext.insert(stored)
        }
        try? modelContext.save()
    }

    func deleteAnamnesis(forClientId clientId: String) {
        let descriptor = FetchDescriptor<StoredClientAnamnesis>(
            predicate: #Predicate { $0.clientId == clientId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
}
