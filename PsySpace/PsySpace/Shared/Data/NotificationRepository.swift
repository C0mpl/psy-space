//
//  NotificationRepository.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class NotificationRepository {
    var pendingNotifications: [CancellationNotification] = []
    var currentNotification: CancellationNotification?

    private let defaults = UserDefaults.standard
    private let lastCheckedKey = "lastCancellationCheck"

    func checkForCancellations(bookings: [Booking], currentUserId: String, isTherapist: Bool) {
        let lastChecked = defaults.object(forKey: lastCheckedKey) as? Date ?? .distantPast

        let newCancellations = bookings.filter { booking in
            guard booking.status == .cancelled,
                  let cancelledAt = booking.cancelledAt,
                  cancelledAt > lastChecked else {
                return false
            }

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

        if let first = pendingNotifications.first {
            currentNotification = first
        }

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
