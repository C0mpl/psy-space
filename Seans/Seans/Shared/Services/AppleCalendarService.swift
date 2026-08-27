//
//  AppleCalendarService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 26.08.2026.
//

import EventKit
import Foundation

@MainActor
final class AppleCalendarService: Sendable {
    static let shared = AppleCalendarService()

    private let eventStore = EKEventStore()
    private let mappingKey = "AppleCalendarEventMappings"

    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var hasFullAccess: Bool {
        authorizationStatus == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            #if DEBUG
            print("📅 Apple Calendar access \(granted ? "granted" : "denied")")
            #endif
            return granted
        } catch {
            #if DEBUG
            print("❌ Apple Calendar access request failed: \(error)")
            #endif
            return false
        }
    }

    func createEvent(for booking: Booking, isTherapist: Bool) async throws -> String {
        guard hasFullAccess else {
            throw AppleCalendarError.noAccess
        }

        let event = EKEvent(eventStore: eventStore)
        configureEvent(event, for: booking, isTherapist: isTherapist)

        try eventStore.save(event, span: .thisEvent)

        saveMapping(bookingId: booking.bookingId, eventId: event.eventIdentifier)

        #if DEBUG
        print("📅 Created Apple Calendar event for booking \(booking.bookingId)")
        #endif

        return event.eventIdentifier
    }

    func updateEvent(for booking: Booking, isTherapist: Bool) async throws {
        guard hasFullAccess else {
            throw AppleCalendarError.noAccess
        }

        guard let eventId = getEventId(for: booking.bookingId),
              let event = eventStore.event(withIdentifier: eventId) else {
            _ = try await createEvent(for: booking, isTherapist: isTherapist)
            return
        }

        configureEvent(event, for: booking, isTherapist: isTherapist)
        try eventStore.save(event, span: .thisEvent)

        #if DEBUG
        print("📅 Updated Apple Calendar event for booking \(booking.bookingId)")
        #endif
    }

    func deleteEvent(for booking: Booking) async throws {
        guard hasFullAccess else {
            throw AppleCalendarError.noAccess
        }

        guard let eventId = getEventId(for: booking.bookingId),
              let event = eventStore.event(withIdentifier: eventId) else {
            #if DEBUG
            print("📅 No Apple Calendar event found to delete for booking \(booking.bookingId)")
            #endif
            return
        }

        try eventStore.remove(event, span: .thisEvent)
        removeMapping(bookingId: booking.bookingId)

        #if DEBUG
        print("📅 Deleted Apple Calendar event for booking \(booking.bookingId)")
        #endif
    }

    func syncAllBookings(_ bookings: [Booking], isTherapist: Bool) async -> Int {
        guard hasFullAccess else { return 0 }

        var synced = 0
        let upcomingBookings = bookings.filter { $0.startTime > .now && $0.status != .cancelled }

        for booking in upcomingBookings {
            do {
                if getEventId(for: booking.bookingId) != nil {
                    try await updateEvent(for: booking, isTherapist: isTherapist)
                } else {
                    _ = try await createEvent(for: booking, isTherapist: isTherapist)
                }
                synced += 1
            } catch {
                #if DEBUG
                print("❌ Failed to sync booking \(booking.bookingId) to Apple Calendar: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("📅 Synced \(synced) bookings to Apple Calendar")
        #endif

        return synced
    }

    private func configureEvent(_ event: EKEvent, for booking: Booking, isTherapist: Bool) {
        if isTherapist {
            event.title = booking.clientName
            event.notes = "Сеанс з клієнтом \(booking.clientName)"
        } else {
            event.title = "Сеанс терапії"
            event.notes = "Сеанс терапії"
        }

        event.startDate = booking.startTime
        event.endDate = booking.endTime
        event.calendar = eventStore.defaultCalendarForNewEvents

        let alarm = EKAlarm(relativeOffset: -3600)
        event.alarms = [alarm]
    }

    private func saveMapping(bookingId: String, eventId: String) {
        var mappings = getMappings()
        mappings[bookingId] = eventId
        UserDefaults.standard.set(mappings, forKey: mappingKey)
    }

    private func removeMapping(bookingId: String) {
        var mappings = getMappings()
        mappings.removeValue(forKey: bookingId)
        UserDefaults.standard.set(mappings, forKey: mappingKey)
    }

    private func getEventId(for bookingId: String) -> String? {
        getMappings()[bookingId]
    }

    private func getMappings() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }
}

enum AppleCalendarError: Error {
    case noAccess
    case eventNotFound
}
