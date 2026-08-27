//
//  CalendarService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 26.08.2026.
//

import Foundation

enum CalendarSyncAction {
    case create
    case update
    case delete
}

@MainActor
final class CalendarService: Sendable {
    static let shared = CalendarService()

    let appleService = AppleCalendarService.shared
    let googleService = GoogleCalendarService.shared

    private init() {}

    func requestAccess() async -> Bool {
        #if DEBUG
        print("📅 CalendarService: Requesting Google Calendar access...")
        #endif

        let googleGranted = await googleService.requestAccess()
        if googleGranted {
            #if DEBUG
            print("✅ CalendarService: Google Calendar access granted")
            #endif
            return true
        }

        #if DEBUG
        print("📅 CalendarService: Google Calendar not available, trying Apple Calendar...")
        #endif

        let appleGranted = await appleService.requestAccess()
        #if DEBUG
        if appleGranted {
            print("✅ CalendarService: Apple Calendar access granted (fallback)")
        } else {
            print("❌ CalendarService: No calendar access granted")
        }
        #endif
        return appleGranted
    }

    var hasAccess: Bool {
        get async {
            let googleAccess = await googleService.hasCalendarAccess
            if googleAccess { return true }
            return appleService.hasFullAccess
        }
    }

    var availableCalendar: CalendarType? {
        get async {
            let googleAccess = await googleService.hasCalendarAccess
            if googleAccess { return .google }
            if appleService.hasFullAccess { return .apple }
            return nil
        }
    }

    func createEvent(for booking: Booking, isTherapist: Bool, clientEmail: String?, therapistEmail: String?) async {
        let googleAccess = await googleService.hasCalendarAccess
        if googleAccess {
            do {
                _ = try await googleService.createEvent(
                    for: booking,
                    isTherapist: isTherapist,
                    clientEmail: clientEmail,
                    therapistEmail: therapistEmail
                )
                return
            } catch {
                #if DEBUG
                print("❌ Google Calendar create failed: \(error)")
                #endif
            }
        }

        if appleService.hasFullAccess {
            do {
                _ = try await appleService.createEvent(for: booking, isTherapist: isTherapist)
            } catch {
                #if DEBUG
                print("❌ Apple Calendar create failed: \(error)")
                #endif
            }
        }
    }

    func updateEvent(for booking: Booking, isTherapist: Bool, clientEmail: String?, therapistEmail: String?) async {
        let googleAccess = await googleService.hasCalendarAccess
        if googleAccess {
            do {
                try await googleService.updateEvent(
                    for: booking,
                    isTherapist: isTherapist,
                    clientEmail: clientEmail,
                    therapistEmail: therapistEmail
                )
                return
            } catch {
                #if DEBUG
                print("❌ Google Calendar update failed: \(error)")
                #endif
            }
        }

        if appleService.hasFullAccess {
            do {
                try await appleService.updateEvent(for: booking, isTherapist: isTherapist)
            } catch {
                #if DEBUG
                print("❌ Apple Calendar update failed: \(error)")
                #endif
            }
        }
    }

    func deleteEvent(for booking: Booking) async {
        let googleAccess = await googleService.hasCalendarAccess
        if googleAccess {
            do {
                try await googleService.deleteEvent(for: booking)
            } catch {
                #if DEBUG
                print("❌ Google Calendar delete failed: \(error)")
                #endif
            }
        }

        if appleService.hasFullAccess {
            do {
                try await appleService.deleteEvent(for: booking)
            } catch {
                #if DEBUG
                print("❌ Apple Calendar delete failed: \(error)")
                #endif
            }
        }
    }

    func syncAllBookings(_ bookings: [Booking], isTherapist: Bool, clientEmail: String?, therapistEmail: String?) async -> Int {
        var synced = 0
        let upcomingBookings = bookings.filter { $0.startTime > .now && $0.status != .cancelled }

        let googleAccess = await googleService.hasCalendarAccess

        for booking in upcomingBookings {
            if googleAccess {
                do {
                    _ = try await googleService.createEvent(
                        for: booking,
                        isTherapist: isTherapist,
                        clientEmail: clientEmail,
                        therapistEmail: therapistEmail
                    )
                    synced += 1
                    continue
                } catch {
                    #if DEBUG
                    print("❌ Failed to sync booking \(booking.bookingId) to Google Calendar: \(error)")
                    #endif
                }
            }

            if appleService.hasFullAccess {
                do {
                    _ = try await appleService.createEvent(for: booking, isTherapist: isTherapist)
                    synced += 1
                } catch {
                    #if DEBUG
                    print("❌ Failed to sync booking \(booking.bookingId) to Apple Calendar: \(error)")
                    #endif
                }
            }
        }

        #if DEBUG
        print("📅 Synced \(synced) bookings to calendar")
        #endif

        return synced
    }
}

enum CalendarType: String, Codable {
    case apple
    case google

    var displayName: String {
        switch self {
        case .apple: return "Apple Calendar"
        case .google: return "Google Calendar"
        }
    }

    var icon: String {
        switch self {
        case .apple: return "calendar"
        case .google: return "g.circle.fill"
        }
    }
}
