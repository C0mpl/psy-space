//
//  UserStorage.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import Foundation
import SwiftData

@Model
final class StoredUser {
    @Attribute(.unique) var appleUserID: String
    var email: String?
    var name: String
    var isTherapist: Bool
    var createdAt: Date

    init(appleUserID: String, email: String?, name: String, isTherapist: Bool, createdAt: Date = .now) {
        self.appleUserID = appleUserID
        self.email = email
        self.name = name
        self.isTherapist = isTherapist
        self.createdAt = createdAt
    }

    func toUser() -> User {
        User(
            id: appleUserID,
            email: email,
            name: name,
            isTherapist: isTherapist,
            createdAt: createdAt
        )
    }
}

@MainActor
final class UserStorage {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelContainer.mainContext }

    init() throws {
        let schema = Schema([StoredUser.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        self.modelContainer = try ModelContainer(for: schema, configurations: config)
    }

    func loadUser() -> User? {
        let descriptor = FetchDescriptor<StoredUser>()
        guard let storedUser = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return storedUser.toUser()
    }

    func saveUser(_ user: User) {
        // Delete existing user if any
        let descriptor = FetchDescriptor<StoredUser>()
        if let existing = try? modelContext.fetch(descriptor) {
            existing.forEach { modelContext.delete($0) }
        }

        // Insert new user
        let storedUser = StoredUser(
            appleUserID: user.id,
            email: user.email,
            name: user.name,
            isTherapist: user.isTherapist,
            createdAt: user.createdAt
        )
        modelContext.insert(storedUser)
        try? modelContext.save()
    }

    func updateUser(appleUserID: String, name: String?, email: String?) {
        let descriptor = FetchDescriptor<StoredUser>(
            predicate: #Predicate { $0.appleUserID == appleUserID }
        )
        guard let storedUser = try? modelContext.fetch(descriptor).first else { return }

        if let name, !name.isEmpty {
            storedUser.name = name
        }
        if let email {
            storedUser.email = email
        }
        try? modelContext.save()
    }

    func deleteUser() {
        let descriptor = FetchDescriptor<StoredUser>()
        if let existing = try? modelContext.fetch(descriptor) {
            existing.forEach { modelContext.delete($0) }
        }
        try? modelContext.save()
    }
}
