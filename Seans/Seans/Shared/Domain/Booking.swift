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
    var date: Date
    var startTime: Date
    var endTime: Date
    var status: BookingStatus
    let createdAt: Date
    var cancelledAt: Date?
    var cancelledBy: CancelledBy?
    var cancellationReason: String?
    var rescheduledAt: Date?
    var rescheduledBy: CancelledBy?
    var previousStartTime: Date?

    var bookingId: String { id ?? UUID().uuidString }

    init(
        id: String? = nil,
        clientId: String,
        clientName: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        status: BookingStatus = .confirmed,
        createdAt: Date = .now,
        cancelledAt: Date? = nil,
        cancelledBy: CancelledBy? = nil,
        cancellationReason: String? = nil,
        rescheduledAt: Date? = nil,
        rescheduledBy: CancelledBy? = nil,
        previousStartTime: Date? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.clientId = clientId
        self.clientName = clientName
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.createdAt = createdAt
        self.cancelledAt = cancelledAt
        self.cancelledBy = cancelledBy
        self.cancellationReason = cancellationReason
        self.rescheduledAt = rescheduledAt
        self.rescheduledBy = rescheduledBy
        self.previousStartTime = previousStartTime
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

enum CancelledBy: String, Codable, Sendable {
    case client
    case therapist
}
