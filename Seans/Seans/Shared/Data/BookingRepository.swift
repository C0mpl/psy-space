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
        slot: TimeSlot
    ) async throws(BookingError) {
        // Check if slot is already booked
        let isSlotTaken = bookings.contains { booking in
            booking.startTime == slot.startTime &&
            Calendar.current.isDate(booking.date, inSameDayAs: date) &&
            booking.status != .cancelled
        }

        if isSlotTaken {
            throw .slotUnavailable
        }

        let booking = Booking(
            clientId: clientId,
            clientName: clientName,
            date: date,
            startTime: slot.startTime,
            endTime: slot.endTime
        )

        do {
            try await firestore.createBooking(booking)
        } catch {
            throw .unknown
        }
    }

    func cancelBooking(_ bookingId: String) async {
        guard let index = bookings.firstIndex(where: { $0.id == bookingId }) else { return }

        var booking = bookings[index]
        booking.status = .cancelled

        do {
            try await firestore.updateBooking(booking)
        } catch {
            self.error = .unknown
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
