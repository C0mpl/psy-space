//
//  GoogleCalendarService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 26.08.2026.
//

import Foundation

@MainActor
final class GoogleCalendarService: Sendable {
    static let shared = GoogleCalendarService()

    private let authService = AuthService.shared
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let mappingKey = "GoogleCalendarEventMappings"

    private init() {}

    var hasCalendarAccess: Bool {
        get async {
            await authService.hasCalendarAccess
        }
    }

    func requestAccess() async -> Bool {
        do {
            #if DEBUG
            print("📅 GoogleCalendarService: Requesting calendar scope...")
            #endif
            let granted = try await authService.requestCalendarAccess()
            #if DEBUG
            print("📅 GoogleCalendarService: Calendar scope request result: \(granted)")
            #endif
            return granted
        } catch {
            #if DEBUG
            print("❌ GoogleCalendarService: Failed to request calendar access: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Localized: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    func createEvent(for booking: Booking, isTherapist: Bool, clientEmail: String?, therapistEmail: String?) async throws -> String {
        let accessToken = try await authService.getValidAccessToken()

        let event = GoogleCalendarEvent(
            summary: isTherapist ? booking.clientName : "Сеанс терапії",
            description: isTherapist ? "Сеанс з клієнтом \(booking.clientName)" : "Сеанс терапії",
            start: EventDateTime(dateTime: booking.startTime),
            end: EventDateTime(dateTime: booking.endTime),
            attendees: buildAttendees(clientEmail: clientEmail, therapistEmail: therapistEmail, isTherapist: isTherapist),
            conferenceData: ConferenceDataRequest(
                createRequest: CreateConferenceRequest(
                    requestId: booking.bookingId,
                    conferenceSolutionKey: ConferenceSolutionKey(type: "hangoutsMeet")
                )
            ),
            reminders: EventReminders(
                useDefault: false,
                overrides: [ReminderOverride(method: "popup", minutes: 60)]
            )
        )

        let url = URL(string: "\(baseURL)/calendars/primary/events?conferenceDataVersion=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(event)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Calendar API error (\(httpResponse.statusCode)): \(errorString)")
            }
            #endif
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        let createdEvent = try JSONDecoder().decode(GoogleCalendarEventResponse.self, from: data)

        saveMapping(bookingId: booking.bookingId, eventId: createdEvent.id)

        #if DEBUG
        print("📅 Created Google Calendar event for booking \(booking.bookingId)")
        if let meetLink = createdEvent.hangoutLink {
            print("   Meet link: \(meetLink)")
        }
        #endif

        return createdEvent.id
    }

    func updateEvent(for booking: Booking, isTherapist: Bool, clientEmail: String?, therapistEmail: String?) async throws {
        guard let eventId = getEventId(for: booking.bookingId) else {
            _ = try await createEvent(for: booking, isTherapist: isTherapist, clientEmail: clientEmail, therapistEmail: therapistEmail)
            return
        }

        let accessToken = try await authService.getValidAccessToken()

        let event = GoogleCalendarEvent(
            summary: isTherapist ? booking.clientName : "Сеанс терапії",
            description: isTherapist ? "Сеанс з клієнтом \(booking.clientName)" : "Сеанс терапії",
            start: EventDateTime(dateTime: booking.startTime),
            end: EventDateTime(dateTime: booking.endTime),
            attendees: buildAttendees(clientEmail: clientEmail, therapistEmail: therapistEmail, isTherapist: isTherapist),
            conferenceData: nil,
            reminders: EventReminders(
                useDefault: false,
                overrides: [ReminderOverride(method: "popup", minutes: 60)]
            )
        )

        let url = URL(string: "\(baseURL)/calendars/primary/events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(event)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Google Calendar API update error (\(httpResponse.statusCode)): \(errorString)")
            }
            #endif
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        #if DEBUG
        print("📅 Updated Google Calendar event for booking \(booking.bookingId)")
        #endif
    }

    func deleteEvent(for booking: Booking) async throws {
        guard let eventId = getEventId(for: booking.bookingId) else {
            #if DEBUG
            print("📅 No Google Calendar event found to delete for booking \(booking.bookingId)")
            #endif
            return
        }

        let accessToken = try await authService.getValidAccessToken()

        let url = URL(string: "\(baseURL)/calendars/primary/events/\(eventId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCalendarError.networkError
        }

        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 410 else {
            throw GoogleCalendarError.apiError(httpResponse.statusCode)
        }

        removeMapping(bookingId: booking.bookingId)

        #if DEBUG
        print("📅 Deleted Google Calendar event for booking \(booking.bookingId)")
        #endif
    }

    func syncAllBookings(_ bookings: [Booking], isTherapist: Bool, clientEmail: String?, therapistEmail: String?) async -> Int {
        let hasAccess = await hasCalendarAccess
        guard hasAccess else { return 0 }

        var synced = 0
        let upcomingBookings = bookings.filter { $0.startTime > .now && $0.status != .cancelled }

        for booking in upcomingBookings {
            do {
                if getEventId(for: booking.bookingId) != nil {
                    try await updateEvent(for: booking, isTherapist: isTherapist, clientEmail: clientEmail, therapistEmail: therapistEmail)
                } else {
                    _ = try await createEvent(for: booking, isTherapist: isTherapist, clientEmail: clientEmail, therapistEmail: therapistEmail)
                }
                synced += 1
            } catch {
                #if DEBUG
                print("❌ Failed to sync booking \(booking.bookingId) to Google Calendar: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("📅 Synced \(synced) bookings to Google Calendar")
        #endif

        return synced
    }

    private func buildAttendees(clientEmail: String?, therapistEmail: String?, isTherapist: Bool) -> [EventAttendee]? {
        var attendees: [EventAttendee] = []

        if let clientEmail {
            attendees.append(EventAttendee(email: clientEmail))
        }
        if let therapistEmail {
            attendees.append(EventAttendee(email: therapistEmail))
        }

        return attendees.isEmpty ? nil : attendees
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

enum GoogleCalendarError: Error {
    case noAccess
    case eventNotFound
    case networkError
    case apiError(Int)
}

private struct GoogleCalendarEvent: Encodable {
    let summary: String
    let description: String
    let start: EventDateTime
    let end: EventDateTime
    let attendees: [EventAttendee]?
    let conferenceData: ConferenceDataRequest?
    let reminders: EventReminders
}

private struct EventDateTime: Encodable {
    let dateTime: Date
    let timeZone: String = TimeZone.current.identifier
}

private struct EventAttendee: Encodable {
    let email: String
}

private struct ConferenceDataRequest: Encodable {
    let createRequest: CreateConferenceRequest
}

private struct CreateConferenceRequest: Encodable {
    let requestId: String
    let conferenceSolutionKey: ConferenceSolutionKey
}

private struct ConferenceSolutionKey: Encodable {
    let type: String
}

private struct EventReminders: Encodable {
    let useDefault: Bool
    let overrides: [ReminderOverride]
}

private struct ReminderOverride: Encodable {
    let method: String
    let minutes: Int
}

private struct GoogleCalendarEventResponse: Decodable {
    let id: String
    let hangoutLink: String?
}
