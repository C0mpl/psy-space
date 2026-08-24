//
//  Availability.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import Foundation

// MARK: - Weekly Schedule

struct WeeklySchedule: Codable, Equatable, Sendable {
    var monday: DaySchedule?
    var tuesday: DaySchedule?
    var wednesday: DaySchedule?
    var thursday: DaySchedule?
    var friday: DaySchedule?
    var saturday: DaySchedule?
    var sunday: DaySchedule?

    static let empty = WeeklySchedule()

    func schedule(for weekday: Int) -> DaySchedule? {
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return nil
        }
    }

    mutating func setSchedule(_ schedule: DaySchedule?, for weekday: Int) {
        switch weekday {
        case 1: sunday = schedule
        case 2: monday = schedule
        case 3: tuesday = schedule
        case 4: wednesday = schedule
        case 5: thursday = schedule
        case 6: friday = schedule
        case 7: saturday = schedule
        default: break
        }
    }
}

struct DaySchedule: Codable, Equatable, Sendable {
    var startTime: TimeOfDay
    var endTime: TimeOfDay
    var isEnabled: Bool

    init(startTime: TimeOfDay = .init(hour: 9, minute: 0),
         endTime: TimeOfDay = .init(hour: 17, minute: 0),
         isEnabled: Bool = true) {
        self.startTime = startTime
        self.endTime = endTime
        self.isEnabled = isEnabled
    }
}

struct TimeOfDay: Codable, Equatable, Comparable, Sendable {
    var hour: Int
    var minute: Int

    var totalMinutes: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    func toDate(on date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - Availability Settings

struct AvailabilitySettings: Codable, Equatable, Sendable {
    var maxSessionsPerWeek: Int
    var sessionDurationMinutes: Int
    var breakBetweenSessionsMinutes: Int
    var weeklySchedule: WeeklySchedule

    static let `default` = AvailabilitySettings(
        maxSessionsPerWeek: 20,
        sessionDurationMinutes: 60,
        breakBetweenSessionsMinutes: 15,
        weeklySchedule: .empty
    )
}

// MARK: - Time Slot

struct TimeSlot: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let isBooked: Bool

    var startTimeFormatted: String {
        startTime.formatted(date: .omitted, time: .shortened)
    }

    var endTimeFormatted: String {
        endTime.formatted(date: .omitted, time: .shortened)
    }
}
