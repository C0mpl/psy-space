//
//  HomeworkRepository.swift
//  PsySpace
//
//  Created by Claude on 03.09.2026.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class HomeworkRepository {
    var homework: [Homework] = []
    var responses: [HomeworkResponse] = []
    var isLoading = false
    var error: HomeworkError?

    private let firestore = FirestoreService.shared
    private let storageService = StorageService.shared
    private var storage: HomeworkStorage?
    private var homeworkListener: ListenerRegistration?
    private var responsesListener: ListenerRegistration?
    private var clientId: String?

    init() {
        do {
            storage = try HomeworkStorage()
        } catch {
            #if DEBUG
            print("HomeworkRepository: Failed to initialize storage: \(error)")
            #endif
        }
    }

    // MARK: - Therapist Listeners

    func startListeningToHomework(forClientId clientId: String) {
        homeworkListener?.remove()
        self.clientId = clientId

        if let storage {
            homework = storage.loadHomework(forClientId: clientId)
            #if DEBUG
            print("HomeworkRepository: Loaded \(homework.count) cached homework items")
            #endif
        }

        homeworkListener = firestore.listenToHomework(forClientId: clientId) { [weak self] homework in
            Task { @MainActor in
                #if DEBUG
                print("HomeworkRepository: Received \(homework.count) homework items from Firestore")
                #endif
                self?.homework = homework
                self?.storage?.saveHomeworkList(homework)
            }
        }
    }

    func startListeningToSharedResponses(forClientId clientId: String) {
        responsesListener?.remove()

        if let storage {
            responses = storage.loadResponses(forClientId: clientId).filter { $0.isShared }
            #if DEBUG
            print("HomeworkRepository: Loaded \(responses.count) cached shared responses")
            #endif
        }

        responsesListener = firestore.listenToSharedHomeworkResponses(forClientId: clientId) { [weak self] responses in
            Task { @MainActor in
                #if DEBUG
                print("HomeworkRepository: Received \(responses.count) shared responses from Firestore")
                #endif
                self?.responses = responses
                self?.storage?.saveResponses(responses)
            }
        }
    }

    // MARK: - Client Listeners

    func startListeningToMyHomework(clientId: String) {
        homeworkListener?.remove()
        self.clientId = clientId

        if let storage {
            homework = storage.loadHomework(forClientId: clientId).filter { $0.status == .active }
            #if DEBUG
            print("HomeworkRepository: Loaded \(homework.count) cached active homework items")
            #endif
        }

        homeworkListener = firestore.listenToActiveHomework(forClientId: clientId) { [weak self] homework in
            Task { @MainActor in
                #if DEBUG
                print("HomeworkRepository: Received \(homework.count) active homework items from Firestore")
                #endif
                self?.homework = homework
                self?.storage?.saveHomeworkList(homework)
            }
        }
    }

    func startListeningToMyResponses(clientId: String) {
        responsesListener?.remove()

        if let storage {
            responses = storage.loadResponses(forClientId: clientId)
            #if DEBUG
            print("HomeworkRepository: Loaded \(responses.count) cached responses")
            #endif
        }

        responsesListener = firestore.listenToHomeworkResponses(forClientId: clientId) { [weak self] responses in
            Task { @MainActor in
                #if DEBUG
                print("HomeworkRepository: Received \(responses.count) responses from Firestore")
                #endif
                self?.responses = responses
                self?.storage?.saveResponses(responses)
            }
        }
    }

    func stopListening() {
        homeworkListener?.remove()
        responsesListener?.remove()
        homeworkListener = nil
        responsesListener = nil
        #if DEBUG
        print("HomeworkRepository: Stopped listening")
        #endif
    }

    // MARK: - Helpers

    func response(forHomeworkId homeworkId: String) -> HomeworkResponse? {
        responses.first { $0.homeworkId == homeworkId }
    }

    func homework(withId homeworkId: String) -> Homework? {
        homework.first { $0.homeworkId == homeworkId }
    }

    // MARK: - Therapist Operations

    func createHomework(
        clientId: String,
        title: String,
        instructions: String,
        plainTextInstructions: String,
        attachments: [HomeworkAttachment]
    ) async throws(HomeworkError) {
        let newId = UUID().uuidString
        let hw = Homework(
            id: newId,
            clientId: clientId,
            title: title,
            instructions: instructions,
            plainTextInstructions: plainTextInstructions,
            attachments: attachments,
            status: .active,
            createdAt: .now,
            updatedAt: .now
        )

        homework.insert(hw, at: 0)
        storage?.saveHomework(hw)

        do {
            try await firestore.createHomework(hw)
        } catch {
            homework.removeAll { $0.homeworkId == hw.homeworkId }
            storage?.deleteHomework(hw.homeworkId)
            throw .saveFailed
        }
    }

    func updateHomework(_ hw: Homework) async throws(HomeworkError) {
        var updatedHw = hw
        updatedHw.updatedAt = .now

        guard let index = homework.firstIndex(where: { $0.homeworkId == hw.homeworkId }) else {
            throw .notFound
        }

        let previousHw = homework[index]
        homework[index] = updatedHw
        storage?.saveHomework(updatedHw)

        do {
            try await firestore.updateHomework(updatedHw)
        } catch {
            homework[index] = previousHw
            storage?.saveHomework(previousHw)
            throw .saveFailed
        }
    }

    func archiveHomework(_ homeworkId: String) async throws(HomeworkError) {
        guard let index = homework.firstIndex(where: { $0.homeworkId == homeworkId }) else {
            throw .notFound
        }

        var updatedHw = homework[index]
        updatedHw.status = .archived
        updatedHw.updatedAt = .now

        let previousHw = homework[index]
        homework[index] = updatedHw
        storage?.saveHomework(updatedHw)

        do {
            try await firestore.updateHomework(updatedHw)
        } catch {
            homework[index] = previousHw
            storage?.saveHomework(previousHw)
            throw .saveFailed
        }
    }

    func deleteHomework(_ homeworkId: String) async throws(HomeworkError) {
        guard let index = homework.firstIndex(where: { $0.homeworkId == homeworkId }) else {
            throw .notFound
        }

        let removedHw = homework.remove(at: index)
        storage?.deleteHomework(homeworkId)

        // Delete all attachments from storage
        for attachment in removedHw.attachments where attachment.type == .pdf {
            do {
                try await storageService.deleteHomeworkAttachment(
                    clientId: removedHw.clientId,
                    homeworkId: homeworkId,
                    attachmentId: attachment.attachmentId
                )
            } catch {
                #if DEBUG
                print("HomeworkRepository: Failed to delete attachment: \(error)")
                #endif
            }
        }

        do {
            try await firestore.deleteHomework(homeworkId)
        } catch {
            homework.insert(removedHw, at: index)
            storage?.saveHomework(removedHw)
            throw .deleteFailed
        }
    }

    // MARK: - Attachment Upload

    func uploadAttachment(
        clientId: String,
        homeworkId: String,
        localURL: URL,
        name: String
    ) async throws(HomeworkError) -> HomeworkAttachment {
        let attachmentId = UUID().uuidString

        // Get file size
        let fileSize: Int?
        if let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path),
           let size = attrs[.size] as? Int {
            fileSize = size
        } else {
            fileSize = nil
        }

        do {
            let downloadURL = try await storageService.uploadHomeworkAttachment(
                clientId: clientId,
                homeworkId: homeworkId,
                attachmentId: attachmentId,
                localURL: localURL
            )

            return HomeworkAttachment(
                attachmentId: attachmentId,
                type: .pdf,
                name: name,
                url: downloadURL,
                sizeInBytes: fileSize
            )
        } catch {
            throw .uploadFailed
        }
    }

    // MARK: - Client Operations

    func createOrUpdateResponse(
        homeworkId: String,
        clientId: String,
        content: String,
        plainTextContent: String,
        isCompleted: Bool,
        isShared: Bool
    ) async throws(HomeworkError) {
        var updatedResponse: HomeworkResponse

        if var existing = response(forHomeworkId: homeworkId) {
            existing.content = content
            existing.plainTextContent = plainTextContent
            existing.isCompleted = isCompleted
            existing.isShared = isShared
            existing.updatedAt = .now
            updatedResponse = existing
        } else {
            let newId = UUID().uuidString
            updatedResponse = HomeworkResponse(
                id: newId,
                homeworkId: homeworkId,
                clientId: clientId,
                content: content,
                plainTextContent: plainTextContent,
                isCompleted: isCompleted,
                isShared: isShared,
                createdAt: .now,
                updatedAt: .now
            )
        }

        let previousResponse = response(forHomeworkId: homeworkId)

        if let index = responses.firstIndex(where: { $0.homeworkId == homeworkId }) {
            responses[index] = updatedResponse
        } else {
            responses.insert(updatedResponse, at: 0)
        }
        storage?.saveResponse(updatedResponse)

        do {
            if previousResponse != nil {
                try await firestore.updateHomeworkResponse(updatedResponse)
            } else {
                try await firestore.createHomeworkResponse(updatedResponse)
            }
        } catch {
            if let previousResponse {
                if let index = responses.firstIndex(where: { $0.homeworkId == homeworkId }) {
                    responses[index] = previousResponse
                }
                storage?.saveResponse(previousResponse)
            } else {
                responses.removeAll { $0.homeworkId == homeworkId }
                storage?.deleteResponse(updatedResponse.responseId)
            }
            throw .saveFailed
        }
    }

    func toggleCompletion(forHomeworkId homeworkId: String, clientId: String) async throws(HomeworkError) {
        guard let existing = response(forHomeworkId: homeworkId) else {
            // Create a new response with just completion toggled
            try await createOrUpdateResponse(
                homeworkId: homeworkId,
                clientId: clientId,
                content: "",
                plainTextContent: "",
                isCompleted: true,
                isShared: false
            )
            return
        }

        try await createOrUpdateResponse(
            homeworkId: homeworkId,
            clientId: clientId,
            content: existing.content,
            plainTextContent: existing.plainTextContent,
            isCompleted: !existing.isCompleted,
            isShared: existing.isShared
        )
    }

    func toggleSharing(forHomeworkId homeworkId: String, clientId: String) async throws(HomeworkError) {
        guard let existing = response(forHomeworkId: homeworkId) else {
            throw .notFound
        }

        try await createOrUpdateResponse(
            homeworkId: homeworkId,
            clientId: clientId,
            content: existing.content,
            plainTextContent: existing.plainTextContent,
            isCompleted: existing.isCompleted,
            isShared: !existing.isShared
        )
    }
}

enum HomeworkError: Error {
    case saveFailed
    case deleteFailed
    case uploadFailed
    case notFound
    case unknown
}
