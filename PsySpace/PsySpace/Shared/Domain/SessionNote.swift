//
//  SessionNote.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 28.08.2026.
//

import FirebaseFirestore
import Foundation

struct SessionNote: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let bookingId: String
    let clientId: String
    var hypotheses: String
    var observations: String
    var plainTextContent: String
    let createdAt: Date
    var updatedAt: Date

    var noteId: String { id ?? UUID().uuidString }

    init(
        id: String? = nil,
        bookingId: String,
        clientId: String,
        hypotheses: String = "",
        observations: String = "",
        plainTextContent: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id ?? UUID().uuidString
        self.bookingId = bookingId
        self.clientId = clientId
        self.hypotheses = hypotheses
        self.observations = observations
        self.plainTextContent = plainTextContent
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
        let combined = [hypotheses, observations]
            .map { extractPlainText(from: $0) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }

    var isEmpty: Bool {
        plainTextContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func extractPlainText(from serialized: String) -> String {
        if let data = Data(base64Encoded: serialized),
           let decoded = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            return decoded.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return serialized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
