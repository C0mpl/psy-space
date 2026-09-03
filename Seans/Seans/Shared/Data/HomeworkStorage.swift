//
//  HomeworkStorage.swift
//  Seans
//
//  Created by Claude on 03.09.2026.
//

import Foundation
import SwiftData

@Model
final class StoredHomework {
    @Attribute(.unique) var homeworkId: String
    var clientId: String
    var title: String
    var instructions: String
    var plainTextInstructions: String
    var attachmentsData: Data?
    var status: String
    var createdAt: Date
    var updatedAt: Date

    init(
        homeworkId: String,
        clientId: String,
        title: String,
        instructions: String,
        plainTextInstructions: String,
        attachmentsData: Data?,
        status: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.homeworkId = homeworkId
        self.clientId = clientId
        self.title = title
        self.instructions = instructions
        self.plainTextInstructions = plainTextInstructions
        self.attachmentsData = attachmentsData
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toHomework() -> Homework {
        var attachments: [HomeworkAttachment] = []
        if let data = attachmentsData {
            attachments = (try? JSONDecoder().decode([HomeworkAttachment].self, from: data)) ?? []
        }

        return Homework(
            id: homeworkId,
            clientId: clientId,
            title: title,
            instructions: instructions,
            plainTextInstructions: plainTextInstructions,
            attachments: attachments,
            status: HomeworkStatus(rawValue: status) ?? .active,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from homework: Homework) {
        title = homework.title
        instructions = homework.instructions
        plainTextInstructions = homework.plainTextInstructions
        attachmentsData = try? JSONEncoder().encode(homework.attachments)
        status = homework.status.rawValue
        updatedAt = homework.updatedAt
    }
}

@Model
final class StoredHomeworkResponse {
    @Attribute(.unique) var responseId: String
    var homeworkId: String
    var clientId: String
    var content: String
    var plainTextContent: String
    var isCompleted: Bool
    var isShared: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        responseId: String,
        homeworkId: String,
        clientId: String,
        content: String,
        plainTextContent: String,
        isCompleted: Bool,
        isShared: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.responseId = responseId
        self.homeworkId = homeworkId
        self.clientId = clientId
        self.content = content
        self.plainTextContent = plainTextContent
        self.isCompleted = isCompleted
        self.isShared = isShared
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func toHomeworkResponse() -> HomeworkResponse {
        HomeworkResponse(
            id: responseId,
            homeworkId: homeworkId,
            clientId: clientId,
            content: content,
            plainTextContent: plainTextContent,
            isCompleted: isCompleted,
            isShared: isShared,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from response: HomeworkResponse) {
        content = response.content
        plainTextContent = response.plainTextContent
        isCompleted = response.isCompleted
        isShared = response.isShared
        updatedAt = response.updatedAt
    }
}

@MainActor
final class HomeworkStorage {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelContainer.mainContext }

    init() throws {
        let schema = Schema([StoredHomework.self, StoredHomeworkResponse.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Homework

    func loadHomework(forClientId clientId: String) -> [Homework] {
        let descriptor = FetchDescriptor<StoredHomework>(
            predicate: #Predicate { $0.clientId == clientId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let homework = try? modelContext.fetch(descriptor) else {
            return []
        }
        return homework.map { $0.toHomework() }
    }

    func loadHomework(homeworkId: String) -> Homework? {
        let descriptor = FetchDescriptor<StoredHomework>(
            predicate: #Predicate { $0.homeworkId == homeworkId }
        )
        guard let stored = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return stored.toHomework()
    }

    func saveHomework(_ homework: Homework) {
        let homeworkId = homework.homeworkId
        let descriptor = FetchDescriptor<StoredHomework>(
            predicate: #Predicate { $0.homeworkId == homeworkId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: homework)
        } else {
            let stored = StoredHomework(
                homeworkId: homework.homeworkId,
                clientId: homework.clientId,
                title: homework.title,
                instructions: homework.instructions,
                plainTextInstructions: homework.plainTextInstructions,
                attachmentsData: try? JSONEncoder().encode(homework.attachments),
                status: homework.status.rawValue,
                createdAt: homework.createdAt,
                updatedAt: homework.updatedAt
            )
            modelContext.insert(stored)
        }
        try? modelContext.save()
    }

    func saveHomeworkList(_ homeworkList: [Homework]) {
        for homework in homeworkList {
            saveHomework(homework)
        }
    }

    func deleteHomework(_ homeworkId: String) {
        let descriptor = FetchDescriptor<StoredHomework>(
            predicate: #Predicate { $0.homeworkId == homeworkId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }

    // MARK: - Homework Responses

    func loadResponses(forClientId clientId: String) -> [HomeworkResponse] {
        let descriptor = FetchDescriptor<StoredHomeworkResponse>(
            predicate: #Predicate { $0.clientId == clientId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let responses = try? modelContext.fetch(descriptor) else {
            return []
        }
        return responses.map { $0.toHomeworkResponse() }
    }

    func loadResponse(forHomeworkId homeworkId: String) -> HomeworkResponse? {
        let descriptor = FetchDescriptor<StoredHomeworkResponse>(
            predicate: #Predicate { $0.homeworkId == homeworkId }
        )
        guard let stored = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return stored.toHomeworkResponse()
    }

    func saveResponse(_ response: HomeworkResponse) {
        let responseId = response.responseId
        let descriptor = FetchDescriptor<StoredHomeworkResponse>(
            predicate: #Predicate { $0.responseId == responseId }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.update(from: response)
        } else {
            let stored = StoredHomeworkResponse(
                responseId: response.responseId,
                homeworkId: response.homeworkId,
                clientId: response.clientId,
                content: response.content,
                plainTextContent: response.plainTextContent,
                isCompleted: response.isCompleted,
                isShared: response.isShared,
                createdAt: response.createdAt,
                updatedAt: response.updatedAt
            )
            modelContext.insert(stored)
        }
        try? modelContext.save()
    }

    func saveResponses(_ responses: [HomeworkResponse]) {
        for response in responses {
            saveResponse(response)
        }
    }

    func deleteResponse(_ responseId: String) {
        let descriptor = FetchDescriptor<StoredHomeworkResponse>(
            predicate: #Predicate { $0.responseId == responseId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
}
