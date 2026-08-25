//
//  BookingRepository.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class BookingRepository {
    // MARK: - State

    var bookings: [Booking] = []
    var isLoading = false
    var error: BookingError?

    // MARK: - Private

    private let firestore = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var clientId: String?

    // MARK: - Init

    init() {}

    // MARK: - Listening

    func startListening(forClientId clientId: String? = nil) {
        listener?.remove()
        self.clientId = clientId

        if let clientId {
            // Client only sees their own bookings
            listener = firestore.listenToBookings(forClientId: clientId) { [weak self] bookings in
                Task { @MainActor in
                    self?.bookings = bookings
                }
            }
        } else {
            // Therapist sees all bookings
            listener = firestore.listenToBookings { [weak self] bookings in
                Task { @MainActor in
                    self?.bookings = bookings
                }
            }
        }
    }

    // MARK: - Fetch

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            bookings = try await firestore.fetchBookings()
        } catch {
            self.error = .unknown
        }
    }

    // MARK: - CRUD

    func createBooking(
        clientId: String,
        clientName: String,
        date: Date,
        slot: TimeSlot,
        maxSessionsPerDay: Int? = nil
    ) async throws(BookingError) {
        let calendar = Calendar.current

        // Get confirmed bookings for this day
        let dayBookings = bookings.filter { booking in
            calendar.isDate(booking.date, inSameDayAs: date) && booking.status != .cancelled
        }

        // Check if slot is already booked (compare timestamps to avoid Date precision issues)
        let slotTimestamp = slot.startTime.timeIntervalSince1970
        let isSlotTaken = dayBookings.contains { booking in
            abs(booking.startTime.timeIntervalSince1970 - slotTimestamp) < 60 // Within 1 minute
        }

        if isSlotTaken {
            throw .slotUnavailable
        }

        // Check daily limit
        if let maxSessions = maxSessionsPerDay, dayBookings.count >= maxSessions {
            throw .maxSessionsReached
        }

        let booking = Booking(
            clientId: clientId,
            clientName: clientName,
            date: date,
            startTime: slot.startTime,
            endTime: slot.endTime
        )

        // Optimistic update - add to local list immediately
        bookings.append(booking)

        do {
            try await firestore.createBooking(booking)
        } catch {
            // Rollback optimistic update on failure
            bookings.removeAll { $0.bookingId == booking.bookingId }
            throw .unknown
        }
    }

    func cancelBooking(_ bookingId: String, by cancelledBy: CancelledBy, reason: String? = nil) async {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return }

        var booking = bookings[index]
        booking.status = .cancelled
        booking.cancelledAt = .now
        booking.cancelledBy = cancelledBy
        booking.cancellationReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? reason : nil

        do {
            try await firestore.updateBooking(booking)
        } catch {
            self.error = .unknown
        }
    }

    func rescheduleBooking(
        _ bookingId: String,
        to newSlot: TimeSlot,
        newDate: Date,
        by rescheduledBy: CancelledBy
    ) async throws(BookingError) {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else {
            throw .unknown
        }

        let calendar = Calendar.current

        // Check if new slot is available (exclude current booking from check)
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
        booking.previousStartTime = booking.startTime
        booking.date = newDate
        booking.startTime = newSlot.startTime
        booking.endTime = newSlot.endTime
        booking.rescheduledAt = .now
        booking.rescheduledBy = rescheduledBy

        do {
            try await firestore.updateBooking(booking)
        } catch {
            throw .unknown
        }
    }

    // MARK: - Queries

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
}

enum BookingError: Error {
    case slotUnavailable
    case maxSessionsReached
    case unknown
}
