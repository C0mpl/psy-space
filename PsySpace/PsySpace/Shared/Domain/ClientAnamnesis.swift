//
//  ClientAnamnesis.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import FirebaseFirestore
import Foundation

struct ClientAnamnesis: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let clientId: String
    var background: String
    var presentingIssues: String
    var treatmentGoals: String
    var plainTextSummary: String
    let createdAt: Date
    var updatedAt: Date

    var anamnesisId: String { id ?? clientId }

    init(
        id: String? = nil,
        clientId: String,
        background: String = "",
        presentingIssues: String = "",
        treatmentGoals: String = "",
        plainTextSummary: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id ?? clientId
        self.clientId = clientId
        self.background = background
        self.presentingIssues = presentingIssues
        self.treatmentGoals = treatmentGoals
        self.plainTextSummary = plainTextSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var createdAtFormatted: String {
        createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var updatedAtFormatted: String {
        updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var isEmpty: Bool {
        plainTextSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var preview: String {
        let trimmed = plainTextSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 150 {
            return String(trimmed.prefix(150)) + "..."
        }
        return trimmed
    }
}
