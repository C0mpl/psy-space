//
//  Availability.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import Foundation

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
    var timeWindows: [TimeWindow]
    var isEnabled: Bool
    var maxSessionsPerDay: Int?

    private var startTime: TimeOfDay?
    private var endTime: TimeOfDay?

    init(
        timeWindows: [TimeWindow] = [TimeWindow()],
        isEnabled: Bool = true,
        maxSessionsPerDay: Int? = nil
    ) {
        self.timeWindows = timeWindows
        self.isEnabled = isEnabled
        self.maxSessionsPerDay = maxSessionsPerDay
        self.startTime = nil
        self.endTime = nil
    }

    init(
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        isEnabled: Bool = true,
        maxSessionsPerDay: Int? = nil
    ) {
        self.timeWindows = [TimeWindow(startTime: startTime, endTime: endTime)]
        self.isEnabled = isEnabled
        self.maxSessionsPerDay = maxSessionsPerDay
        self.startTime = nil
        self.endTime = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        maxSessionsPerDay = try container.decodeIfPresent(Int.self, forKey: .maxSessionsPerDay)

        if let windows = try? container.decode([TimeWindow].self, forKey: .timeWindows) {
            timeWindows = windows
            startTime = nil
            endTime = nil
        } else {
            let legacyStart = try container.decode(TimeOfDay.self, forKey: .startTime)
            let legacyEnd = try container.decode(TimeOfDay.self, forKey: .endTime)
            timeWindows = [TimeWindow(startTime: legacyStart, endTime: legacyEnd)]
            startTime = legacyStart
            endTime = legacyEnd
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeWindows, forKey: .timeWindows)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(maxSessionsPerDay, forKey: .maxSessionsPerDay)
        if let first = timeWindows.first {
            try container.encode(first.startTime, forKey: .startTime)
            try container.encode(first.endTime, forKey: .endTime)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case timeWindows, isEnabled, maxSessionsPerDay, startTime, endTime
    }

    var totalMinutes: Int {
        timeWindows.reduce(0) { $0 + $1.totalMinutes }
    }

    var formattedSummary: String {
        timeWindows.map { $0.formatted }.joined(separator: ", ")
    }
}

struct TimeWindow: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var startTime: TimeOfDay
    var endTime: TimeOfDay

    init(
        id: String = UUID().uuidString,
        startTime: TimeOfDay = .init(hour: 9, minute: 0),
        endTime: TimeOfDay = .init(hour: 17, minute: 0)
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }

    var totalMinutes: Int {
        endTime.totalMinutes - startTime.totalMinutes
    }

    var formatted: String {
        "\(startTime.formatted)-\(endTime.formatted)"
    }

    var isValid: Bool {
        startTime < endTime
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

struct AvailabilitySettings: Codable, Equatable, Sendable {
    var maxSessionsPerWeek: Int
    var sessionDurationMinutes: Int
    var breakBetweenSessionsMinutes: Int
    var weeklySchedule: WeeklySchedule
    var sessionPriceUAH: Int

    static let `default` = AvailabilitySettings(
        maxSessionsPerWeek: 20,
        sessionDurationMinutes: 60,
        breakBetweenSessionsMinutes: 15,
        weeklySchedule: .empty,
        sessionPriceUAH: 1500
    )
}

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
