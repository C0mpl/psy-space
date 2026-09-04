//
//  BookingRepository.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class BookingRepository {
    var bookings: [Booking] = []
    var isLoading = false
    var error: BookingError?

    private let firestore = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var clientId: String?

    init() {}

    func startListening(forClientId clientId: String? = nil) {
        listener?.remove()
        self.clientId = clientId

        #if DEBUG
        print("📡 BookingRepository: Starting listener (clientId: \(clientId ?? "all"))")
        #endif

        if let clientId {
            listener = firestore.listenToBookings(forClientId: clientId) { [weak self] bookings in
                Task { @MainActor in
                    #if DEBUG
                    print("📡 BookingRepository: Received \(bookings.count) bookings for client")
                    for booking in bookings {
                        if booking.rescheduleRequest != nil {
                            print("   - Booking \(booking.bookingId) has reschedule request: \(booking.rescheduleRequest!.status)")
                        }
                    }
                    #endif
                    self?.bookings = bookings
                }
            }
        } else {
            listener = firestore.listenToBookings { [weak self] bookings in
                Task { @MainActor in
                    #if DEBUG
                    print("📡 BookingRepository: Received \(bookings.count) bookings for therapist")
                    for booking in bookings {
                        if booking.rescheduleRequest != nil {
                            print("   - Booking \(booking.bookingId) has reschedule request: \(booking.rescheduleRequest!.status)")
                        }
                    }
                    #endif
                    self?.bookings = bookings
                }
            }
        }
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            bookings = try await firestore.fetchBookings()
        } catch {
            self.error = .unknown
        }
    }

    func createBooking(
        clientId: String,
        clientName: String,
        clientEmail: String? = nil,
        date: Date,
        slot: TimeSlot,
        maxSessionsPerDay: Int? = nil,
        paymentId: String? = nil,
        paidAmount: Int? = nil,
        usedCreditAmount: Int? = nil
    ) async throws(BookingError) {
        let calendar = Calendar.current

        let dayBookings = bookings.filter { booking in
            calendar.isDate(booking.date, inSameDayAs: date) && booking.status != .cancelled
        }

        let slotTimestamp = slot.startTime.timeIntervalSince1970
        let isSlotTaken = dayBookings.contains { booking in
            abs(booking.startTime.timeIntervalSince1970 - slotTimestamp) < 60
        }

        if isSlotTaken {
            throw .slotUnavailable
        }

        if let maxSessions = maxSessionsPerDay, dayBookings.count >= maxSessions {
            throw .maxSessionsReached
        }

        let booking = Booking(
            clientId: clientId,
            clientName: clientName,
            clientEmail: clientEmail,
            date: date,
            startTime: slot.startTime,
            endTime: slot.endTime,
            paymentId: paymentId,
            paymentStatus: paymentId != nil ? .success : nil,
            paidAmount: paidAmount,
            usedCreditAmount: usedCreditAmount
        )

        bookings.append(booking)

        do {
            try await firestore.createBooking(booking)
        } catch {
            bookings.removeAll { $0.bookingId == booking.bookingId }
            throw .unknown
        }
    }

    struct CancellationResult {
        let creditAmount: Int?
        let refundedAmount: Int?
        let refundSuccess: Bool
    }

    @discardableResult
    func cancelBooking(
        _ bookingId: String,
        by cancelledBy: CancelledBy,
        reason: String? = nil,
        refund: Bool = false,
        paymentRepo: PaymentRepository? = nil
    ) async -> CancellationResult {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            return CancellationResult(creditAmount: nil, refundedAmount: nil, refundSuccess: false)
        }

        var booking = bookings[index]
        let hasPaidAmount = booking.paidAmount != nil && booking.paidAmount! > 0
        let qualifiesForCompensation = booking.canCancelWithCredit && hasPaidAmount

        booking.status = .cancelled
        booking.cancelledAt = .now
        booking.cancelledBy = cancelledBy
        booking.cancellationReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? reason : nil

        var result = CancellationResult(creditAmount: nil, refundedAmount: nil, refundSuccess: false)

        let usedCredit = booking.usedCreditAmount ?? 0

        if refund, let paymentId = booking.paymentId, let amount = booking.paidAmount, amount > 0, let paymentRepo {
            do {
                let success = try await paymentRepo.refundPayment(
                    invoiceId: paymentId,
                    reference: booking.bookingId,
                    amount: nil
                )

                if success {
                    booking.refundedAt = .now
                    booking.refundedAmount = amount
                    booking.paymentStatus = .refunded
                    booking.creditGivenOnCancel = false

                    if usedCredit > 0 {
                        try? await firestore.addUserCredit(userId: booking.clientId, amount: usedCredit)
                    }

                    result = CancellationResult(creditAmount: usedCredit > 0 ? usedCredit : nil, refundedAmount: amount, refundSuccess: true)
                } else {
                    if qualifiesForCompensation {
                        let totalCredit = amount + usedCredit
                        booking.creditGivenOnCancel = true
                        try? await firestore.addUserCredit(userId: booking.clientId, amount: totalCredit)
                        result = CancellationResult(creditAmount: totalCredit, refundedAmount: nil, refundSuccess: false)
                    }
                }
            } catch {
                if qualifiesForCompensation {
                    let totalCredit = amount + usedCredit
                    booking.creditGivenOnCancel = true
                    try? await firestore.addUserCredit(userId: booking.clientId, amount: totalCredit)
                    result = CancellationResult(creditAmount: totalCredit, refundedAmount: nil, refundSuccess: false)
                }
            }
        } else if refund, usedCredit > 0 {
            try? await firestore.addUserCredit(userId: booking.clientId, amount: usedCredit)
            booking.creditGivenOnCancel = true
            result = CancellationResult(creditAmount: usedCredit, refundedAmount: nil, refundSuccess: true)
        } else if qualifiesForCompensation {
            booking.creditGivenOnCancel = true
            let totalCredit = (booking.paidAmount ?? 0) + usedCredit
            if totalCredit > 0 {
                try? await firestore.addUserCredit(userId: booking.clientId, amount: totalCredit)
                result = CancellationResult(creditAmount: totalCredit, refundedAmount: nil, refundSuccess: false)
            }
        }

        do {
            try await firestore.updateBooking(booking)
        } catch {
            self.error = .unknown
        }

        return result
    }

    func requestReschedule(
        _ bookingId: String,
        to newSlot: TimeSlot,
        newDate: Date,
        by requestedBy: CancelledBy
    ) async throws(BookingError) {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            throw .unknown
        }

        let calendar = Calendar.current

        let dayBookings = bookings.filter { booking in
            calendar.isDate(booking.date, inSameDayAs: newDate) &&
            booking.status != .cancelled &&
            booking.id != bookingId
        }

        let slotTimestamp = newSlot.startTime.timeIntervalSince1970
        let isSlotTaken = dayBookings.contains { booking in
            abs(booking.startTime.timeIntervalSince1970 - slotTimestamp) < 60
        }

        if isSlotTaken {
            throw .slotUnavailable
        }

        var booking = bookings[index]

        booking.rescheduleRequest = RescheduleRequest(
            requestedBy: requestedBy,
            requestedAt: .now,
            newDate: newDate,
            newStartTime: newSlot.startTime,
            newEndTime: newSlot.endTime,
            status: .pending
        )

        #if DEBUG
        print("📝 BookingRepository: Creating reschedule request for booking \(bookingId)")
        print("   - Requested by: \(requestedBy)")
        print("   - New date: \(newDate)")
        #endif

        do {
            try await firestore.updateBooking(booking)
            #if DEBUG
            print("✅ BookingRepository: Reschedule request saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ BookingRepository: Failed to save reschedule request: \(error)")
            #endif
            throw .unknown
        }
    }

    func approveReschedule(_ bookingId: String) async throws(BookingError) {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }),
              let request = bookings[index].rescheduleRequest,
              request.status == .pending else {
            throw .unknown
        }

        var booking = bookings[index]

        booking.previousStartTime = booking.startTime
        booking.date = request.newDate
        booking.startTime = request.newStartTime
        booking.endTime = request.newEndTime
        booking.rescheduledAt = .now
        booking.rescheduledBy = request.requestedBy

        booking.rescheduleRequest = nil

        do {
            try await firestore.updateBooking(booking)
        } catch {
            throw .unknown
        }
    }

    func rejectReschedule(_ bookingId: String) async {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }),
              bookings[index].rescheduleRequest?.status == .pending else {
            return
        }

        var booking = bookings[index]
        booking.rescheduleRequest = nil

        do {
            try await firestore.updateBooking(booking)
        } catch {
            self.error = .unknown
        }
    }

    func cancelRescheduleRequest(_ bookingId: String) async {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }),
              bookings[index].rescheduleRequest?.status == .pending else {
            return
        }

        var booking = bookings[index]
        booking.rescheduleRequest = nil

        do {
            try await firestore.updateBooking(booking)
        } catch {
            self.error = .unknown
        }
    }

    func bookings(for date: Date) -> [Booking] {
        let calendar = Calendar.current
        return bookings.filter { booking in
            calendar.isDate(booking.date, inSameDayAs: date) && booking.status != .cancelled
        }
    }

    func upcomingBookings(for clientId: String? = nil) -> [Booking] {
        let now = Date.now
        return bookings
            .filter { booking in
                booking.startTime > now &&
                booking.status != .cancelled &&
                (clientId == nil || booking.clientId == clientId)
            }
            .sorted { $0.startTime < $1.startTime }
    }

    func bookingsThisWeek() -> [Booking] {
        let calendar = Calendar.current
        let now = Date.now
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }

        return bookings.filter { booking in
            booking.date >= weekStart && booking.date < weekEnd && booking.status != .cancelled
        }
    }

    var sessionsThisWeek: Int {
        bookingsThisWeek().count
    }

    func pendingRescheduleRequests(for userId: String, isTherapist: Bool) -> [Booking] {
        bookings.filter { booking in
            guard let request = booking.rescheduleRequest,
                  request.status == .pending else { return false }

            if isTherapist {
                return request.requestedBy == .client
            } else {
                return request.requestedBy == .therapist && booking.clientId == userId
            }
        }
    }

    func myPendingRescheduleRequests(for userId: String, isTherapist: Bool) -> [Booking] {
        bookings.filter { booking in
            guard let request = booking.rescheduleRequest,
                  request.status == .pending else { return false }

            if isTherapist {
                return request.requestedBy == .therapist
            } else {
                return request.requestedBy == .client && booking.clientId == userId
            }
        }
    }
}

enum BookingError: Error {
    case slotUnavailable
    case maxSessionsReached
    case unknown
}
