//
//  FirestoreSessionNoteService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreSessionNoteService: @unchecked Sendable {
    static let shared = FirestoreSessionNoteService()

    private var db: Firestore { Firestore.firestore() }

    private var sessionNotesCollection: CollectionReference {
        db.collection("sessionNotes")
    }

    func createSessionNote(_ note: SessionNote) async throws {
        try sessionNotesCollection.document(note.noteId).setData(from: note)
        #if DEBUG
        print("Session note created: \(note.noteId)")
        #endif
    }

    func updateSessionNote(_ note: SessionNote) async throws {
        try sessionNotesCollection.document(note.noteId).setData(from: note)
        #if DEBUG
        print("Session note updated: \(note.noteId)")
        #endif
    }

    func deleteSessionNote(_ noteId: String) async throws {
        try await sessionNotesCollection.document(noteId).delete()
        #if DEBUG
        print("Session note deleted: \(noteId)")
        #endif
    }

    func fetchSessionNotes(forClientId clientId: String) async throws -> [SessionNote] {
        let snapshot = try await sessionNotesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: SessionNote.self)
        }
    }

    func listenToSessionNotes(
        forClientId clientId: String,
        onChange: @escaping ([SessionNote]) -> Void
    ) -> ListenerRegistration {
        sessionNotesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("FirestoreSessionNoteService: Session notes listener error: \(error)")
                    return
                }
                print("FirestoreSessionNoteService: Session notes received \(snapshot?.documents.count ?? 0) notes")
                #endif
                guard let documents = snapshot?.documents else { return }
                let notes = documents.compactMap { doc in
                    try? doc.data(as: SessionNote.self)
                }
                onChange(notes)
            }
    }
}
