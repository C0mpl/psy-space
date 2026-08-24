//
//  Booking.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import FirebaseFirestore
import Foundation

struct Booking: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let clientId: String
    let clientName: String
    let date: Date
    let startTime: Date
    let endTime: Date
    var status: BookingStatus
    let createdAt: Date

    var bookingId: String { id ?? UUID().uuidString }

    init(
        id: String? = nil,
        clientId: String,
        clientName: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        status: BookingStatus = .confirmed,
        createdAt: Date = .now
    ) {
        self.id = id ?? UUID().uuidString
        self.clientId = clientId
        self.clientName = clientName
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.createdAt = createdAt
    }

    var dateFormatted: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var timeFormatted: String {
        "\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))"
    }
}

enum BookingStatus: String, Codable, Sendable {
    case pending
    case confirmed
    case cancelled
    case completed
}
