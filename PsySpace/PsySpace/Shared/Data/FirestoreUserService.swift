//
//  FirestoreUserService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreUserService: @unchecked Sendable {
    static let shared = FirestoreUserService()

    private var db: Firestore { Firestore.firestore() }

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    private var therapistConfigDocument: DocumentReference {
        db.collection("config").document("therapist")
    }

    func saveTherapistAuthCode(_ authCode: String) async throws {
        try await therapistConfigDocument.setData([
            "calendarAuthCode": authCode,
            "calendarAuthCodeSavedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func saveUser(_ user: User, setTherapistRole: Bool = false) async throws {
        var data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "createdAt": user.createdAt,
            "paymentCredit": user.paymentCredit,
            "calendarSyncEnabled": user.calendarSyncEnabled
        ]

        if setTherapistRole {
            data["isTherapist"] = user.isTherapist
        }

        try await usersCollection.document(user.id).setData(data, merge: true)
        #if DEBUG
        print("✅ User saved to Firestore: \(user.email ?? "no email")")
        #endif
    }

    func createUser(_ user: User) async throws {
        let data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "isTherapist": user.isTherapist,
            "createdAt": user.createdAt,
            "paymentCredit": user.paymentCredit,
            "calendarSyncEnabled": user.calendarSyncEnabled
        ]
        try await usersCollection.document(user.id).setData(data)
        #if DEBUG
        print("✅ New user created in Firestore: \(user.email ?? "no email")")
        #endif
    }

    func addUserCredit(userId: String, amount: Int) async throws {
        try await usersCollection.document(userId).setData([
            "paymentCredit": FieldValue.increment(Int64(amount))
        ], merge: true)
        #if DEBUG
        print("✅ Added \(amount) credit to user \(userId)")
        #endif
    }

    func useUserCredit(userId: String, amount: Int) async throws {
        try await usersCollection.document(userId).setData([
            "paymentCredit": FieldValue.increment(Int64(-amount))
        ], merge: true)
        #if DEBUG
        print("✅ Used \(amount) credit from user \(userId)")
        #endif
    }

    func fetchUser(userId: String) async throws -> User? {
        let doc = try await usersCollection.document(userId).getDocument()
        guard let data = doc.data() else { return nil }

        return User(
            id: userId,
            email: data["email"] as? String,
            name: data["name"] as? String ?? "",
            isTherapist: data["isTherapist"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            paymentCredit: data["paymentCredit"] as? Int ?? 0,
            calendarSyncEnabled: data["calendarSyncEnabled"] as? Bool ?? false
        )
    }

    func fetchTherapist() async throws -> User? {
        let snapshot = try await usersCollection
            .whereField("isTherapist", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            return nil
        }

        let data = doc.data()

        return User(
            id: doc.documentID,
            email: data["email"] as? String,
            name: data["name"] as? String ?? "",
            isTherapist: true,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            paymentCredit: data["paymentCredit"] as? Int ?? 0,
            calendarSyncEnabled: data["calendarSyncEnabled"] as? Bool ?? false
        )
    }

    func listenToUser(userId: String, onChange: @escaping (User?) -> Void) -> ListenerRegistration {
        usersCollection.document(userId).addSnapshotListener { snapshot, error in
            #if DEBUG
            if let error {
                print("❌ FirestoreUserService: User listener error: \(error)")
                return
            }
            #endif

            guard let data = snapshot?.data() else {
                onChange(nil)
                return
            }

            let user = User(
                id: userId,
                email: data["email"] as? String,
                name: data["name"] as? String ?? "",
                isTherapist: data["isTherapist"] as? Bool ?? false,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                paymentCredit: data["paymentCredit"] as? Int ?? 0,
                calendarSyncEnabled: data["calendarSyncEnabled"] as? Bool ?? false
            )

            #if DEBUG
            print("🔥 FirestoreUserService: User updated (credit: \(user.paymentCredit))")
            #endif

            onChange(user)
        }
    }
}
