//
//  SessionNoteRepository.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class SessionNoteRepository {
    var notes: [SessionNote] = []
    var anamnesis: ClientAnamnesis?
    var isLoading = false
    var error: SessionNoteError?

    private let firestore = FirestoreService.shared
    private var storage: SessionNoteStorage?
    private var notesListener: ListenerRegistration?
    private var anamnesisListener: ListenerRegistration?
    private var clientId: String?

    init() {
        do {
            storage = try SessionNoteStorage()
        } catch {
            #if DEBUG
            print("SessionNoteRepository: Failed to initialize storage: \(error)")
            #endif
        }
    }

    func startListening(forClientId clientId: String) {
        notesListener?.remove()
        anamnesisListener?.remove()
        self.clientId = clientId

        if let storage {
            notes = storage.loadNotes(forClientId: clientId)
            anamnesis = storage.loadAnamnesis(forClientId: clientId)
            #if DEBUG
            print("SessionNoteRepository: Loaded \(notes.count) cached notes, anamnesis: \(anamnesis != nil)")
            #endif
        }

        #if DEBUG
        print("SessionNoteRepository: Starting listeners for client \(clientId)")
        #endif

        notesListener = firestore.listenToSessionNotes(forClientId: clientId) { [weak self] notes in
            Task { @MainActor in
                #if DEBUG
                print("SessionNoteRepository: Received \(notes.count) notes from Firestore")
                #endif
                self?.notes = notes
                self?.storage?.saveNotes(notes)
            }
        }

        anamnesisListener = firestore.listenToAnamnesis(forClientId: clientId) { [weak self] anamnesis in
            Task { @MainActor in
                #if DEBUG
                print("SessionNoteRepository: Received anamnesis from Firestore: \(anamnesis != nil)")
                #endif
                self?.anamnesis = anamnesis
                if let anamnesis {
                    self?.storage?.saveAnamnesis(anamnesis)
                }
            }
        }
    }

    func stopListening() {
        notesListener?.remove()
        anamnesisListener?.remove()
        notesListener = nil
        anamnesisListener = nil
        #if DEBUG
        print("SessionNoteRepository: Stopped listening")
        #endif
    }

    // MARK: - Session Notes

    func note(forBookingId bookingId: String) -> SessionNote? {
        notes.first { $0.bookingId == bookingId }
    }

    func createNote(
        bookingId: String,
        clientId: String,
        hypotheses: String,
        observations: String,
        plainTextContent: String
    ) async throws(SessionNoteError) {
        let note = SessionNote(
            bookingId: bookingId,
            clientId: clientId,
            hypotheses: hypotheses,
            observations: observations,
            plainTextContent: plainTextContent
        )

        notes.insert(note, at: 0)
        storage?.saveNote(note)

        do {
            try await firestore.createSessionNote(note)
        } catch {
            notes.removeAll { $0.noteId == note.noteId }
            storage?.deleteNote(note.noteId)
            throw .saveFailed
        }
    }

    func updateNote(_ note: SessionNote) async throws(SessionNoteError) {
        var updatedNote = note
        updatedNote.updatedAt = .now

        guard let index = notes.firstIndex(where: { $0.noteId == note.noteId }) else {
            throw .notFound
        }

        let previousNote = notes[index]
        notes[index] = updatedNote
        storage?.saveNote(updatedNote)

        do {
            try await firestore.updateSessionNote(updatedNote)
        } catch {
            notes[index] = previousNote
            storage?.saveNote(previousNote)
            throw .saveFailed
        }
    }

    func deleteNote(_ noteId: String) async throws(SessionNoteError) {
        guard let index = notes.firstIndex(where: { $0.noteId == noteId }) else {
            throw .notFound
        }

        let removedNote = notes.remove(at: index)
        storage?.deleteNote(noteId)

        do {
            try await firestore.deleteSessionNote(noteId)
        } catch {
            notes.insert(removedNote, at: index)
            storage?.saveNote(removedNote)
            throw .deleteFailed
        }
    }

    // MARK: - Anamnesis

    func createOrUpdateAnamnesis(
        clientId: String,
        background: String,
        presentingIssues: String,
        treatmentGoals: String,
        plainTextSummary: String
    ) async throws(SessionNoteError) {
        var updatedAnamnesis: ClientAnamnesis

        if var existing = anamnesis {
            existing.background = background
            existing.presentingIssues = presentingIssues
            existing.treatmentGoals = treatmentGoals
            existing.plainTextSummary = plainTextSummary
            existing.updatedAt = .now
            updatedAnamnesis = existing
        } else {
            updatedAnamnesis = ClientAnamnesis(
                clientId: clientId,
                background: background,
                presentingIssues: presentingIssues,
                treatmentGoals: treatmentGoals,
                plainTextSummary: plainTextSummary
            )
        }

        let previousAnamnesis = anamnesis
        anamnesis = updatedAnamnesis
        storage?.saveAnamnesis(updatedAnamnesis)

        do {
            try await firestore.saveAnamnesis(updatedAnamnesis)
        } catch {
            anamnesis = previousAnamnesis
            if let previousAnamnesis {
                storage?.saveAnamnesis(previousAnamnesis)
            }
            throw .saveFailed
        }
    }
}

enum SessionNoteError: Error {
    case saveFailed
    case deleteFailed
    case notFound
    case unknown
}
