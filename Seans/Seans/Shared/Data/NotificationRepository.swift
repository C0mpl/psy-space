//
//  NotificationRepository.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class NotificationRepository {
    // MARK: - State

    var pendingNotifications: [CancellationNotification] = []
    var currentNotification: CancellationNotification?

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let lastCheckedKey = "lastCancellationCheck"

    // MARK: - Check for Cancellations

    func checkForCancellations(bookings: [Booking], currentUserId: String, isTherapist: Bool) {
        let lastChecked = defaults.object(forKey: lastCheckedKey) as? Date ?? .distantPast

        let newCancellations = bookings.filter { booking in
            guard booking.status == .cancelled,
                  let cancelledAt = booking.cancelledAt,
                  cancelledAt > lastChecked else {
                return false
            }

            // Show notification only if cancelled by the OTHER party
            if isTherapist {
                return booking.cancelledBy == .client
            } else {
                return booking.cancelledBy == .therapist && booking.clientId == currentUserId
            }
        }

        pendingNotifications = newCancellations.map { booking in
            CancellationNotification(
                id: booking.bookingId,
                booking: booking,
                isFromTherapist: booking.cancelledBy == .therapist
            )
        }

        // Show first notification
        if let first = pendingNotifications.first {
            currentNotification = first
        }

        // Update last checked time
        defaults.set(Date.now, forKey: lastCheckedKey)
    }

    func dismissCurrentNotification() {
        guard let current = currentNotification else { return }
        pendingNotifications.removeAll { $0.id == current.id }
        currentNotification = pendingNotifications.first
    }

    func dismissAll() {
        pendingNotifications.removeAll()
        currentNotification = nil
    }
}

// MARK: - Notification Model

struct CancellationNotification: Identifiable {
    let id: String
    let booking: Booking
    let isFromTherapist: Bool

    var title: String {
        isFromTherapist ? "Сеанс скасовано" : "Клієнт скасував запис"
    }

    var message: String {
        let dateTime = "\(booking.dateFormatted) о \(booking.startTime.formatted(date: .omitted, time: .shortened))"
        if isFromTherapist {
            return "Ваш сеанс на \(dateTime) був скасований терапевтом."
        } else {
            return "\(booking.clientName) скасував запис на \(dateTime)."
        }
    }

    var reason: String? {
        booking.cancellationReason
    }
}
