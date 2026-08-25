//
//  AvailabilityRepository.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import FirebaseFirestore
import Foundation

@Observable
@MainActor
final class AvailabilityRepository {
    // MARK: - State

    var settings: AvailabilitySettings = .default
    var isLoading = false
    var error: Error?

    // MARK: - Private

    private let firestore = FirestoreService.shared
    private var listener: ListenerRegistration?

    // MARK: - Init

    init() {
        startListening()
    }

    // MARK: - Listening

    private func startListening() {
        listener = firestore.listenToAvailability { [weak self] settings in
            Task { @MainActor in
                self?.settings = settings
            }
        }
    }

    // MARK: - Fetch

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            settings = try await firestore.fetchAvailability()
        } catch {
            self.error = error
        }
    }

    // MARK: - Updates

    func updateMaxSessions(_ count: Int) {
        settings.maxSessionsPerWeek = max(1, count)
        saveSettings()
    }

    func updateSessionDuration(_ minutes: Int) {
        settings.sessionDurationMinutes = max(15, minutes)
        saveSettings()
    }

    func updateBreakDuration(_ minutes: Int) {
        settings.breakBetweenSessionsMinutes = max(0, minutes)
        saveSettings()
    }

    func updateDaySchedule(_ schedule: DaySchedule?, for weekday: Int) {
        settings.weeklySchedule.setSchedule(schedule, for: weekday)
        saveSettings()
    }

    private func saveSettings() {
        Task {
            do {
                try await firestore.saveAvailability(settings)
            } catch {
                self.error = error
            }
        }
    }

    // MARK: - Slot Generation

    func generateTimeSlots(for date: Date, existingBookings: [Booking]) -> [TimeSlot] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        guard let daySchedule = settings.weeklySchedule.schedule(for: weekday),
              daySchedule.isEnabled else {
            return []
        }

        var slots: [TimeSlot] = []
        let sessionDuration = settings.sessionDurationMinutes
        let breakDuration = settings.breakBetweenSessionsMinutes
        let slotInterval = sessionDuration + breakDuration

        var currentTime = daySchedule.startTime.toDate(on: date, calendar: calendar)
        let endTime = daySchedule.endTime.toDate(on: date, calendar: calendar)

        // Count existing confirmed bookings for this day
        let confirmedBookings = existingBookings.filter { $0.status != .cancelled }
        let bookedCount = confirmedBookings.count

        // Check if daily limit is reached
        let dailyLimitReached = daySchedule.maxSessionsPerDay.map { bookedCount >= $0 } ?? false

        while currentTime.addingTimeInterval(TimeInterval(sessionDuration * 60)) <= endTime {
            let slotEnd = currentTime.addingTimeInterval(TimeInterval(sessionDuration * 60))

            let currentTimestamp = currentTime.timeIntervalSince1970
            let isBookedByTime = confirmedBookings.contains { booking in
                abs(booking.startTime.timeIntervalSince1970 - currentTimestamp) < 60 // Within 1 minute
            }

            // Slot is unavailable if it's booked OR if daily limit is reached
            let isUnavailable = isBookedByTime || (dailyLimitReached && !isBookedByTime)

            let slot = TimeSlot(
                id: "\(date.timeIntervalSince1970)-\(currentTime.timeIntervalSince1970)",
                date: date,
                startTime: currentTime,
                endTime: slotEnd,
                isBooked: isUnavailable
            )
            slots.append(slot)

            currentTime = currentTime.addingTimeInterval(TimeInterval(slotInterval * 60))
        }

        return slots
    }

    // MARK: - Helpers

    func isWorkingDay(_ weekday: Int) -> Bool {
        settings.weeklySchedule.schedule(for: weekday)?.isEnabled ?? false
    }

    func workingDays() -> [Int] {
        (1...7).filter { isWorkingDay($0) }
    }
}
