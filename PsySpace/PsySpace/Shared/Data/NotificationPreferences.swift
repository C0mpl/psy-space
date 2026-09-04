//
//  NotificationPreferences.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 04.09.2026.
//

import Foundation

enum ReminderTiming: String, CaseIterable, Identifiable {
    case oneHour = "1h"
    case threeHours = "3h"
    case oneDay = "1d"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneHour: "1 година"
        case .threeHours: "3 години"
        case .oneDay: "1 день"
        }
    }
}

@Observable
@MainActor
final class NotificationPreferences {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "notifications.isEnabled"
        static let bookingConfirmations = "notifications.bookingConfirmations"
        static let cancellationAlerts = "notifications.cancellationAlerts"
        static let sessionReminders = "notifications.sessionReminders"
        static let reminderTiming = "notifications.reminderTiming"
        static let newBookingAlerts = "notifications.newBookingAlerts"
    }

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
        }
    }

    var bookingConfirmations: Bool {
        didSet {
            defaults.set(bookingConfirmations, forKey: Keys.bookingConfirmations)
        }
    }

    var cancellationAlerts: Bool {
        didSet {
            defaults.set(cancellationAlerts, forKey: Keys.cancellationAlerts)
        }
    }

    var sessionReminders: Bool {
        didSet {
            defaults.set(sessionReminders, forKey: Keys.sessionReminders)
        }
    }

    var reminderTiming: ReminderTiming {
        didSet {
            defaults.set(reminderTiming.rawValue, forKey: Keys.reminderTiming)
        }
    }

    var newBookingAlerts: Bool {
        didSet {
            defaults.set(newBookingAlerts, forKey: Keys.newBookingAlerts)
        }
    }

    init() {
        // Default all to true if not previously set
        if defaults.object(forKey: Keys.isEnabled) == nil {
            defaults.set(true, forKey: Keys.isEnabled)
        }
        if defaults.object(forKey: Keys.bookingConfirmations) == nil {
            defaults.set(true, forKey: Keys.bookingConfirmations)
        }
        if defaults.object(forKey: Keys.cancellationAlerts) == nil {
            defaults.set(true, forKey: Keys.cancellationAlerts)
        }
        if defaults.object(forKey: Keys.sessionReminders) == nil {
            defaults.set(true, forKey: Keys.sessionReminders)
        }
        if defaults.object(forKey: Keys.reminderTiming) == nil {
            defaults.set(ReminderTiming.oneHour.rawValue, forKey: Keys.reminderTiming)
        }
        if defaults.object(forKey: Keys.newBookingAlerts) == nil {
            defaults.set(true, forKey: Keys.newBookingAlerts)
        }

        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.bookingConfirmations = defaults.bool(forKey: Keys.bookingConfirmations)
        self.cancellationAlerts = defaults.bool(forKey: Keys.cancellationAlerts)
        self.sessionReminders = defaults.bool(forKey: Keys.sessionReminders)
        self.newBookingAlerts = defaults.bool(forKey: Keys.newBookingAlerts)

        if let timingRaw = defaults.string(forKey: Keys.reminderTiming),
           let timing = ReminderTiming(rawValue: timingRaw) {
            self.reminderTiming = timing
        } else {
            self.reminderTiming = .oneHour
        }
    }
}
