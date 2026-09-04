//
//  JournalRepository.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class JournalRepository {
    var entries: [JournalEntry] = []
    var isLoading = false
    var error: JournalError?

    private let firestore = FirestoreService.shared
    private var storage: JournalStorage?
    private var listener: ListenerRegistration?
    private var clientId: String?

    init() {
        do {
            storage = try JournalStorage()
        } catch {
            #if DEBUG
            print("❌ JournalRepository: Failed to initialize storage: \(error)")
            #endif
        }
    }

    func startListening(forClientId clientId: String) {
        listener?.remove()
        self.clientId = clientId

        if let storage {
            entries = storage.loadEntries(forClientId: clientId)
            #if DEBUG
            print("📱 JournalRepository: Loaded \(entries.count) cached entries")
            #endif
        }

        #if DEBUG
        print("📡 JournalRepository: Starting listener for client \(clientId)")
        #endif

        listener = firestore.listenToJournalEntries(forClientId: clientId) { [weak self] entries in
            Task { @MainActor in
                #if DEBUG
                print("📡 JournalRepository: Received \(entries.count) entries from Firestore")
                #endif
                self?.entries = entries
                self?.storage?.saveEntries(entries)
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        #if DEBUG
        print("📡 JournalRepository: Stopped listening")
        #endif
    }

    func createEntry(
        clientId: String,
        title: String,
        content: String,
        plainTextContent: String,
        mood: Mood?,
        isShared: Bool,
        audioLocalURL: URL? = nil,
        audioDuration: TimeInterval? = nil
    ) async throws(JournalError) {
        var entry = JournalEntry(
            clientId: clientId,
            title: title,
            content: content,
            plainTextContent: plainTextContent,
            mood: mood,
            isShared: isShared,
            audioDuration: audioDuration
        )

        // Upload audio if present
        if let audioURL = audioLocalURL {
            do {
                let remoteURL = try await StorageService.shared.uploadJournalAudio(
                    clientId: clientId,
                    entryId: entry.entryId,
                    localURL: audioURL
                )
                entry.audioURL = remoteURL
            } catch {
                #if DEBUG
                print("❌ JournalRepository: Failed to upload audio: \(error)")
                #endif
                throw .audioUploadFailed
            }
        }

        entries.insert(entry, at: 0)
        storage?.saveEntry(entry)

        do {
            try await firestore.createJournalEntry(entry)
        } catch {
            entries.removeAll { $0.entryId == entry.entryId }
            storage?.deleteEntry(entry.entryId)
            throw .saveFailed
        }
    }

    func updateEntry(_ entry: JournalEntry) async throws(JournalError) {
        var updatedEntry = entry
        updatedEntry.updatedAt = .now

        guard let index = entries.firstIndex(where: { $0.entryId == entry.entryId }) else {
            throw .notFound
        }

        let previousEntry = entries[index]
        entries[index] = updatedEntry
        storage?.saveEntry(updatedEntry)

        do {
            try await firestore.updateJournalEntry(updatedEntry)
        } catch {
            entries[index] = previousEntry
            storage?.saveEntry(previousEntry)
            throw .saveFailed
        }
    }

    func deleteEntry(_ entryId: String) async throws(JournalError) {
        guard let index = entries.firstIndex(where: { $0.entryId == entryId }) else {
            throw .notFound
        }

        let removedEntry = entries.remove(at: index)
        storage?.deleteEntry(entryId)

        do {
            try await firestore.deleteJournalEntry(entryId)
        } catch {
            entries.insert(removedEntry, at: index)
            storage?.saveEntry(removedEntry)
            throw .deleteFailed
        }
    }

    func entry(byId entryId: String) -> JournalEntry? {
        entries.first { $0.entryId == entryId }
    }

    var recentEntries: [JournalEntry] {
        Array(entries.prefix(5))
    }

    func entries(forMood mood: Mood) -> [JournalEntry] {
        entries.filter { $0.mood == mood }
    }

    var sharedEntries: [JournalEntry] {
        entries.filter { $0.isShared }
    }

    var privateEntries: [JournalEntry] {
        entries.filter { !$0.isShared }
    }

    // MARK: - Therapist Access (Shared Entries Only)

    func startListeningToSharedEntries(forClientId clientId: String) {
        listener?.remove()
        self.clientId = clientId
        entries = []

        #if DEBUG
        print("📡 JournalRepository: Starting shared entries listener for client \(clientId)")
        #endif

        listener = firestore.listenToSharedJournalEntries(forClientId: clientId) { [weak self] entries in
            Task { @MainActor in
                #if DEBUG
                print("📡 JournalRepository: Received \(entries.count) shared entries from Firestore")
                #endif
                self?.entries = entries
            }
        }
    }
}

enum JournalError: Error {
    case saveFailed
    case deleteFailed
    case notFound
    case audioUploadFailed
    case unknown
}
