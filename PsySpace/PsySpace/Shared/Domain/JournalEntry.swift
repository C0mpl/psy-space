//
//  JournalEntry.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 27.08.2026.
//

import FirebaseFirestore
import Foundation

struct JournalEntry: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let clientId: String
    var title: String
    var content: String
    var plainTextContent: String
    var mood: Mood?
    var isShared: Bool
    var audioURL: String?
    var audioDuration: TimeInterval?
    let createdAt: Date
    var updatedAt: Date

    var entryId: String { id ?? UUID().uuidString }

    var hasAudio: Bool { audioURL != nil }

    init(
        id: String? = nil,
        clientId: String,
        title: String = "",
        content: String = "",
        plainTextContent: String = "",
        mood: Mood? = nil,
        isShared: Bool = false,
        audioURL: String? = nil,
        audioDuration: TimeInterval? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id ?? UUID().uuidString
        self.clientId = clientId
        self.title = title
        self.content = content
        self.plainTextContent = plainTextContent
        self.mood = mood
        self.isShared = isShared
        self.audioURL = audioURL
        self.audioDuration = audioDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var createdAtFormatted: String {
        createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var updatedAtFormatted: String {
        updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var preview: String {
        let trimmed = plainTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
}

enum Mood: Int, Codable, CaseIterable, Sendable {
    case veryBad = 1
    case bad = 2
    case neutral = 3
    case good = 4
    case veryGood = 5

    var emoji: String {
        switch self {
        case .veryBad: "😢"
        case .bad: "😔"
        case .neutral: "😐"
        case .good: "🙂"
        case .veryGood: "😊"
        }
    }

    var label: String {
        switch self {
        case .veryBad: "Дуже погано"
        case .bad: "Погано"
        case .neutral: "Нейтрально"
        case .good: "Добре"
        case .veryGood: "Чудово"
        }
    }
}
