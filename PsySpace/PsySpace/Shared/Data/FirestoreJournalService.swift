//
//  FirestoreJournalService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreJournalService: @unchecked Sendable {
    static let shared = FirestoreJournalService()

    private var db: Firestore { Firestore.firestore() }

    private var journalEntriesCollection: CollectionReference {
        db.collection("journalEntries")
    }

    func createJournalEntry(_ entry: JournalEntry) async throws {
        try journalEntriesCollection.document(entry.entryId).setData(from: entry)
        #if DEBUG
        print("✅ Journal entry created: \(entry.entryId)")
        #endif
    }

    func updateJournalEntry(_ entry: JournalEntry) async throws {
        try journalEntriesCollection.document(entry.entryId).setData(from: entry)
        #if DEBUG
        print("✅ Journal entry updated: \(entry.entryId)")
        #endif
    }

    func deleteJournalEntry(_ entryId: String) async throws {
        try await journalEntriesCollection.document(entryId).delete()
        #if DEBUG
        print("✅ Journal entry deleted: \(entryId)")
        #endif
    }

    func fetchJournalEntries(forClientId clientId: String) async throws -> [JournalEntry] {
        let snapshot = try await journalEntriesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: JournalEntry.self)
        }
    }

    func listenToJournalEntries(
        forClientId clientId: String,
        onChange: @escaping ([JournalEntry]) -> Void
    ) -> ListenerRegistration {
        journalEntriesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreJournalService: Journal listener error: \(error)")
                    return
                }
                print("🔥 FirestoreJournalService: Journal received \(snapshot?.documents.count ?? 0) entries")
                #endif
                guard let documents = snapshot?.documents else { return }
                let entries = documents.compactMap { doc in
                    try? doc.data(as: JournalEntry.self)
                }
                onChange(entries)
            }
    }

    func listenToSharedJournalEntries(
        forClientId clientId: String,
        onChange: @escaping ([JournalEntry]) -> Void
    ) -> ListenerRegistration {
        #if DEBUG
        print("🔍 FirestoreJournalService: Setting up shared entries listener for clientId: '\(clientId)'")
        #endif
        return journalEntriesCollection
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreJournalService: Shared journal listener error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
                #endif
                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("🔥 FirestoreJournalService: No documents found for clientId: '\(clientId)'")
                    #endif
                    onChange([])
                    return
                }
                #if DEBUG
                print("🔥 FirestoreJournalService: Found \(documents.count) total documents for clientId: '\(clientId)'")
                #endif
                let entries = documents.compactMap { doc in
                    try? doc.data(as: JournalEntry.self)
                }
                .filter { $0.isShared }
                .sorted { $0.createdAt > $1.createdAt }
                #if DEBUG
                print("🔥 FirestoreJournalService: After filtering isShared=true: \(entries.count) entries")
                #endif
                onChange(entries)
            }
    }
}
