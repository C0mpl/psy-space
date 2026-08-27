//
//  User.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 23.08.2026.
//

import Foundation

struct User: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let email: String?
    let name: String
    let isTherapist: Bool
    let createdAt: Date
    var paymentCredit: Int
    var calendarSyncEnabled: Bool

    init(
        id: String = UUID().uuidString,
        email: String? = nil,
        name: String,
        isTherapist: Bool,
        createdAt: Date = .now,
        paymentCredit: Int = 0,
        calendarSyncEnabled: Bool = false
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.isTherapist = isTherapist
        self.createdAt = createdAt
        self.paymentCredit = paymentCredit
        self.calendarSyncEnabled = calendarSyncEnabled
    }

    var paymentCreditUAH: Int {
        paymentCredit / 100
    }

    var hasCredit: Bool {
        paymentCredit > 0
    }
}
