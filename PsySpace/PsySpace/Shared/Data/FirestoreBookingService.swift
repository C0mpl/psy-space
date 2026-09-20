//
//  FirestoreBookingService.swift
//  PsySpace
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreBookingService: @unchecked Sendable {
    static let shared = FirestoreBookingService()

    private var db: Firestore { Firestore.firestore() }

    private var bookingsCollection: CollectionReference {
        db.collection("bookings")
    }

    private var pendingBookingsCollection: CollectionReference {
        db.collection("pendingBookings")
    }

    func fetchBookings() async throws -> [Booking] {
        let snapshot = try await bookingsCollection
            .order(by: "startTime", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Booking.self)
        }
    }

    func createBooking(_ booking: Booking) async throws {
        try bookingsCollection.document(booking.bookingId).setData(from: booking)
    }

    func updateBooking(_ booking: Booking) async throws {
        #if DEBUG
        print("🔥 FirestoreBookingService: Updating booking \(booking.bookingId)")
        if let request = booking.rescheduleRequest {
            print("   - Has reschedule request: \(request.status)")
        } else {
            print("   - No reschedule request (will be cleared)")
        }
        #endif
        try bookingsCollection.document(booking.bookingId).setData(from: booking)
        #if DEBUG
        print("✅ FirestoreBookingService: Booking updated")
        #endif
    }

    func deleteBooking(_ bookingId: String) async throws {
        try await bookingsCollection.document(bookingId).delete()
    }

    func listenToBookings(onChange: @escaping ([Booking]) -> Void) -> ListenerRegistration {
        bookingsCollection
            .order(by: "startTime", descending: false)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreBookingService: Listener error: \(error)")
                    return
                }
                print("🔥 FirestoreBookingService: Received snapshot with \(snapshot?.documents.count ?? 0) documents")
                #endif
                guard let documents = snapshot?.documents else { return }
                let bookings = documents.compactMap { doc -> Booking? in
                    do {
                        let booking = try doc.data(as: Booking.self)
                        #if DEBUG
                        if booking.rescheduleRequest != nil {
                            print("   - Decoded booking \(booking.bookingId) with reschedule request")
                        }
                        #endif
                        return booking
                    } catch {
                        #if DEBUG
                        print("❌ FirestoreBookingService: Failed to decode booking \(doc.documentID): \(error)")
                        #endif
                        return nil
                    }
                }
                onChange(bookings)
            }
    }

    func listenToBookings(forClientId clientId: String, onChange: @escaping ([Booking]) -> Void) -> ListenerRegistration {
        bookingsCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "startTime", descending: false)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreBookingService: Client listener error: \(error)")
                    return
                }
                print("🔥 FirestoreBookingService: Client received snapshot with \(snapshot?.documents.count ?? 0) documents")
                #endif
                guard let documents = snapshot?.documents else { return }
                let bookings = documents.compactMap { doc -> Booking? in
                    do {
                        let booking = try doc.data(as: Booking.self)
                        #if DEBUG
                        if booking.rescheduleRequest != nil {
                            print("   - Client decoded booking \(booking.bookingId) with reschedule request")
                        }
                        #endif
                        return booking
                    } catch {
                        #if DEBUG
                        print("❌ FirestoreBookingService: Client failed to decode booking \(doc.documentID): \(error)")
                        #endif
                        return nil
                    }
                }
                onChange(bookings)
            }
    }

    func createPendingBooking(_ booking: Booking) async throws {
        try pendingBookingsCollection.document(booking.bookingId).setData(from: booking)
    }

    func deletePendingBooking(_ bookingId: String) async throws {
        try await pendingBookingsCollection.document(bookingId).delete()
    }

    func fetchPendingBooking(_ bookingId: String) async throws -> Booking? {
        let doc = try await pendingBookingsCollection.document(bookingId).getDocument()
        return try? doc.data(as: Booking.self)
    }
}
