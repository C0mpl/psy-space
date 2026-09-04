import Foundation
import FirebaseFirestore

struct HomeworkResponse: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let homeworkId: String
    let clientId: String
    var content: String
    var plainTextContent: String
    var isCompleted: Bool
    var isShared: Bool
    let createdAt: Date
    var updatedAt: Date

    var responseId: String { id ?? UUID().uuidString }

    var preview: String {
        let trimmed = plainTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }

    var hasContent: Bool {
        !plainTextContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var updatedAtFormatted: String {
        updatedAt.formatted(date: .abbreviated, time: .omitted)
    }
}
