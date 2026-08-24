//
//  User.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import Foundation

struct User: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let email: String?
    let name: String
    let isTherapist: Bool
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        email: String? = nil,
        name: String,
        isTherapist: Bool,
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.isTherapist = isTherapist
        self.createdAt = createdAt
    }
}
