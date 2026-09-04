import Foundation
import FirebaseFirestore

struct Homework: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let clientId: String
    var title: String
    var instructions: String
    var plainTextInstructions: String
    var attachments: [HomeworkAttachment]
    var status: HomeworkStatus
    let createdAt: Date
    var updatedAt: Date

    var homeworkId: String { id ?? UUID().uuidString }

    var preview: String {
        let trimmed = plainTextInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }

    var hasAttachments: Bool { !attachments.isEmpty }

    var pdfAttachments: [HomeworkAttachment] {
        attachments.filter { $0.type == .pdf }
    }

    var linkAttachments: [HomeworkAttachment] {
        attachments.filter { $0.type == .link }
    }

    var updatedAtFormatted: String {
        updatedAt.formatted(date: .abbreviated, time: .omitted)
    }

    var createdAtFormatted: String {
        createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}

struct HomeworkAttachment: Codable, Equatable, Sendable, Identifiable {
    let attachmentId: String
    let type: AttachmentType
    let name: String
    let url: String
    let sizeInBytes: Int?

    var id: String { attachmentId }

    var formattedSize: String? {
        guard let bytes = sizeInBytes else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

enum AttachmentType: String, Codable, Sendable {
    case pdf
    case link
}

enum HomeworkStatus: String, Codable, Sendable {
    case active
    case archived
}
