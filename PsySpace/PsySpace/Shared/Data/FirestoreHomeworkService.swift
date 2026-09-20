//
//  FirestoreHomeworkService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreHomeworkService: @unchecked Sendable {
    static let shared = FirestoreHomeworkService()

    private var db: Firestore { Firestore.firestore() }

    private var homeworkCollection: CollectionReference {
        db.collection("homework")
    }

    private var homeworkResponsesCollection: CollectionReference {
        db.collection("homeworkResponses")
    }

    // MARK: - Homework

    func createHomework(_ homework: Homework) async throws {
        try homeworkCollection.document(homework.homeworkId).setData(from: homework)
        #if DEBUG
        print("✅ Homework created: \(homework.homeworkId)")
        #endif
    }

    func updateHomework(_ homework: Homework) async throws {
        try homeworkCollection.document(homework.homeworkId).setData(from: homework)
        #if DEBUG
        print("✅ Homework updated: \(homework.homeworkId)")
        #endif
    }

    func deleteHomework(_ homeworkId: String) async throws {
        try await homeworkCollection.document(homeworkId).delete()
        #if DEBUG
        print("✅ Homework deleted: \(homeworkId)")
        #endif
    }

    func fetchHomework(forClientId clientId: String) async throws -> [Homework] {
        let snapshot = try await homeworkCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Homework.self)
        }
    }

    func listenToHomework(
        forClientId clientId: String,
        onChange: @escaping ([Homework]) -> Void
    ) -> ListenerRegistration {
        homeworkCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreHomeworkService: Homework listener error: \(error)")
                    return
                }
                print("🔥 FirestoreHomeworkService: Homework received \(snapshot?.documents.count ?? 0) items")
                #endif
                guard let documents = snapshot?.documents else { return }
                let homework = documents.compactMap { doc in
                    try? doc.data(as: Homework.self)
                }
                onChange(homework)
            }
    }

    func listenToActiveHomework(
        forClientId clientId: String,
        onChange: @escaping ([Homework]) -> Void
    ) -> ListenerRegistration {
        homeworkCollection
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreHomeworkService: Active homework listener error: \(error)")
                    return
                }
                #endif
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                let homework = documents.compactMap { doc in
                    try? doc.data(as: Homework.self)
                }
                .filter { $0.status == .active }
                .sorted { $0.createdAt > $1.createdAt }
                #if DEBUG
                print("🔥 FirestoreHomeworkService: Active homework: \(homework.count) items")
                #endif
                onChange(homework)
            }
    }

    // MARK: - Homework Responses

    func createHomeworkResponse(_ response: HomeworkResponse) async throws {
        try homeworkResponsesCollection.document(response.responseId).setData(from: response)
        #if DEBUG
        print("✅ Homework response created: \(response.responseId)")
        #endif
    }

    func updateHomeworkResponse(_ response: HomeworkResponse) async throws {
        try homeworkResponsesCollection.document(response.responseId).setData(from: response)
        #if DEBUG
        print("✅ Homework response updated: \(response.responseId)")
        #endif
    }

    func deleteHomeworkResponse(_ responseId: String) async throws {
        try await homeworkResponsesCollection.document(responseId).delete()
        #if DEBUG
        print("✅ Homework response deleted: \(responseId)")
        #endif
    }

    func fetchHomeworkResponses(forClientId clientId: String) async throws -> [HomeworkResponse] {
        let snapshot = try await homeworkResponsesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: HomeworkResponse.self)
        }
    }

    func listenToHomeworkResponses(
        forClientId clientId: String,
        onChange: @escaping ([HomeworkResponse]) -> Void
    ) -> ListenerRegistration {
        homeworkResponsesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreHomeworkService: Homework responses listener error: \(error)")
                    return
                }
                print("🔥 FirestoreHomeworkService: Homework responses received \(snapshot?.documents.count ?? 0) items")
                #endif
                guard let documents = snapshot?.documents else { return }
                let responses = documents.compactMap { doc in
                    try? doc.data(as: HomeworkResponse.self)
                }
                onChange(responses)
            }
    }

    func listenToSharedHomeworkResponses(
        forClientId clientId: String,
        onChange: @escaping ([HomeworkResponse]) -> Void
    ) -> ListenerRegistration {
        homeworkResponsesCollection
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreHomeworkService: Shared homework responses listener error: \(error)")
                    return
                }
                #endif
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                let responses = documents.compactMap { doc in
                    try? doc.data(as: HomeworkResponse.self)
                }
                .filter { $0.isShared }
                .sorted { $0.createdAt > $1.createdAt }
                #if DEBUG
                print("🔥 FirestoreHomeworkService: Shared homework responses: \(responses.count) items")
                #endif
                onChange(responses)
            }
    }
}
