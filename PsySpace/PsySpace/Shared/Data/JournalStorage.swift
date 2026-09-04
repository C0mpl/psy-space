//
//  JournalStorage.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import Foundation
import SwiftData

@Model
final class StoredJournalEntry {
    @Attribute(.unique) var entryId: String
    var clientId: String
    var title: String
    var content: String
    var plainTextContent: String
    var moodValue: Int?
    var isShared: Bool
    var audioURL: String?
    var audioDuration: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        entryId: String,
        clientId: String,
        title: String,
        content: String,
        plainTextContent: String,
        moodValue: Int?,
        isShared: Bool,
        audioURL: String?,
        audioDuration: Double?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.entryId = entryId
        self.clientId = clientId
        self.title = title
        self.content = content
        self.plainTextContent = plainTextContent
        self.moodValue = moodValue
        self.isShared = isShared
        self.audioURL = audioURL
        self.audioDuration = audioDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toJournalEntry() -> JournalEntry {
        JournalEntry(
            id: entryId,
            clientId: clientId,
            title: title,
            content: content,
            plainTextContent: plainTextContent,
            mood: moodValue.flatMap { Mood(rawValue: $0) },
            isShared: isShared,
            audioURL: audioURL,
            audioDuration: audioDuration,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from entry: JournalEntry) {
        title = entry.title
        content = entry.content
        plainTextContent = entry.plainTextContent
        moodValue = entry.mood?.rawValue
        isShared = entry.isShared
        audioURL = entry.audioURL
        audioDuration = entry.audioDuration
        updatedAt = entry.updatedAt
    }
}

@MainActor
final class JournalStorage {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelContainer.mainContext }

    init() throws {
        let schema = Schema([StoredJournalEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try ModelContainer(for: schema, configurations: config)
    }

    func loadEntries(forClientId clientId: String) -> [JournalEntry] {
        let descriptor = FetchDescriptor<StoredJournalEntry>(
            predicate: #Predicate { $0.clientId == clientId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let entries = try? modelContext.fetch(descriptor) else {
            return []
        }
        return entries.map { $0.toJournalEntry() }
    }

    func saveEntry(_ entry: JournalEntry) {
        let entryId = entry.entryId
        let descriptor = FetchDescriptor<StoredJournalEntry>(
            predicate: #Predicate { $0.entryId == entryId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: entry)
        } else {
            let stored = StoredJournalEntry(
                entryId: entry.entryId,
                clientId: entry.clientId,
                title: entry.title,
                content: entry.content,
                plainTextContent: entry.plainTextContent,
                moodValue: entry.mood?.rawValue,
                isShared: entry.isShared,
                audioURL: entry.audioURL,
                audioDuration: entry.audioDuration,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
            modelContext.insert(stored)
        }
        try? modelContext.save()
    }

    func saveEntries(_ entries: [JournalEntry]) {
        for entry in entries {
            saveEntry(entry)
        }
    }

    func deleteEntry(_ entryId: String) {
        let descriptor = FetchDescriptor<StoredJournalEntry>(
            predicate: #Predicate { $0.entryId == entryId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    func deleteAllEntries(forClientId clientId: String) {
        let descriptor = FetchDescriptor<StoredJournalEntry>(
            predicate: #Predicate { $0.clientId == clientId }
        )
        if let entries = try? modelContext.fetch(descriptor) {
            entries.forEach { modelContext.delete($0) }
            try? modelContext.save()
        }
    }
}
