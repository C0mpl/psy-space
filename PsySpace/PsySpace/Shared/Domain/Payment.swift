//
//  Payment.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 25.08.2026.
//

import Foundation

struct Payment: Identifiable, Codable, Equatable, Sendable {
    var id: String { invoiceId }
    let invoiceId: String
    let bookingReference: String
    let amount: Int
    let pageUrl: String
    var status: PaymentStatus
    let createdAt: Date
    var paidAt: Date?

    var amountInUAH: Int {
        amount / 100
    }

    var amountFormatted: String {
        "\(amountInUAH) \u{20B4}"
    }
}

enum PaymentStatus: String, Codable, Sendable {
    case pending
    case processing
    case success
    case failure
    case expired
    case refunded

    var isTerminal: Bool {
        switch self {
        case .success, .failure, .expired, .refunded:
            return true
        case .pending, .processing:
            return false
        }
    }
}

enum PaymentError: Error, Sendable {
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case timeout
    case cancelled
}
