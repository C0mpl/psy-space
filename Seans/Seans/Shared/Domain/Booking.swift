//
//  Booking.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

struct Booking: Identifiable, Codable, Equatable, Sendable {
    @DocumentID var id: String?
    let clientId: String
    let clientName: String
    let clientEmail: String?
    var date: Date
    var startTime: Date
    var endTime: Date
    var status: BookingStatus
    let createdAt: Date

    var cancelledAt: Date?
    var cancelledBy: CancelledBy?
    var cancellationReason: String?
    var creditGivenOnCancel: Bool?

    var rescheduledAt: Date?
    var rescheduledBy: CancelledBy?
    var previousStartTime: Date?

    var rescheduleRequest: RescheduleRequest?

    var paymentId: String?
    var paymentStatus: PaymentStatus?
    var paidAmount: Int?
    var usedCreditAmount: Int?

    var refundedAt: Date?
    var refundedAmount: Int?

    var bookingId: String { id ?? UUID().uuidString }

    var isPaid: Bool {
        paymentStatus == .success || (usedCreditAmount ?? 0) > 0
    }

    var hasPendingReschedule: Bool {
        rescheduleRequest != nil
    }

    var hoursUntilSession: Double {
        startTime.timeIntervalSince(.now) / 3600
    }

    var canCancelWithCredit: Bool {
        hoursUntilSession >= 24
    }

    init(
        id: String? = nil,
        clientId: String,
        clientName: String,
        clientEmail: String? = nil,
        date: Date,
        startTime: Date,
        endTime: Date,
        status: BookingStatus = .confirmed,
        createdAt: Date = .now,
        cancelledAt: Date? = nil,
        cancelledBy: CancelledBy? = nil,
        cancellationReason: String? = nil,
        creditGivenOnCancel: Bool? = nil,
        rescheduledAt: Date? = nil,
        rescheduledBy: CancelledBy? = nil,
        previousStartTime: Date? = nil,
        rescheduleRequest: RescheduleRequest? = nil,
        paymentId: String? = nil,
        paymentStatus: PaymentStatus? = nil,
        paidAmount: Int? = nil,
        usedCreditAmount: Int? = nil,
        refundedAt: Date? = nil,
        refundedAmount: Int? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.clientId = clientId
        self.clientName = clientName
        self.clientEmail = clientEmail
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.createdAt = createdAt
        self.cancelledAt = cancelledAt
        self.cancelledBy = cancelledBy
        self.cancellationReason = cancellationReason
        self.creditGivenOnCancel = creditGivenOnCancel
        self.rescheduledAt = rescheduledAt
        self.rescheduledBy = rescheduledBy
        self.previousStartTime = previousStartTime
        self.rescheduleRequest = rescheduleRequest
        self.paymentId = paymentId
        self.paymentStatus = paymentStatus
        self.paidAmount = paidAmount
        self.usedCreditAmount = usedCreditAmount
        self.refundedAt = refundedAt
        self.refundedAmount = refundedAmount
    }

    var dateFormatted: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var timeFormatted: String {
        "\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))"
    }
}

struct RescheduleRequest: Codable, Equatable, Sendable {
    let requestedBy: CancelledBy
    let requestedAt: Date
    let newDate: Date
    let newStartTime: Date
    let newEndTime: Date
    var status: RescheduleStatus

    var newDateFormatted: String {
        newDate.formatted(date: .abbreviated, time: .omitted)
    }

    var newTimeFormatted: String {
        newStartTime.formatted(date: .omitted, time: .shortened)
    }
}

enum RescheduleStatus: String, Codable, Sendable {
    case pending
    case approved
    case rejected
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
