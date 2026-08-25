//
//  FirestoreService.swift
//  Seans
//
//  Created by Claude on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreService: @unchecked Sendable {
    static let shared = FirestoreService()

    private var db: Firestore { Firestore.firestore() }

    // MARK: - Collections

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    private var availabilityDocument: DocumentReference {
        db.collection("config").document("availability")
    }

    private var bookingsCollection: CollectionReference {
        db.collection("bookings")
    }

    // MARK: - Users

    func saveUser(_ user: User) async throws {
        let data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "isTherapist": user.isTherapist,
            "createdAt": user.createdAt
        ]
        try await usersCollection.document(user.id).setData(data, merge: true)
        #if DEBUG
        print("✅ User saved to Firestore: \(user.email ?? "no email")")
        #endif
    }

    // MARK: - Availability

    func fetchAvailability() async throws -> AvailabilitySettings {
        let snapshot = try await availabilityDocument.getDocument()

        guard let data = snapshot.data(),
              let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let settings = try? JSONDecoder().decode(AvailabilitySettings.self, from: jsonData) else {
            return .default
        }

        return settings
    }

    func saveAvailability(_ settings: AvailabilitySettings) async throws {
        let data = try JSONEncoder().encode(settings)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        try await availabilityDocument.setData(dict)
        #if DEBUG
        print("✅ Availability saved to Firestore")
        #endif
    }

    func listenToAvailability(onChange: @escaping (AvailabilitySettings) -> Void) -> ListenerRegistration {
        availabilityDocument.addSnapshotListener { snapshot, error in
            #if DEBUG
            if let error {
                print("❌ Firestore availability error: \(error.localizedDescription)")
                return
            }
            #endif

            guard let data = snapshot?.data() else {
                #if DEBUG
                print("⚠️ No availability data in Firestore yet")
                #endif
                return
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
                  let settings = try? JSONDecoder().decode(AvailabilitySettings.self, from: jsonData) else {
                #if DEBUG
                print("❌ Failed to decode availability data")
                #endif
                return
            }

            #if DEBUG
            print("✅ Availability loaded: \(settings.weeklySchedule)")
            #endif
            onChange(settings)
        }
    }

    // MARK: - Bookings

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
        try bookingsCollection.document(booking.bookingId).setData(from: booking, merge: true)
    }

    func deleteBooking(_ bookingId: String) async throws {
        try await bookingsCollection.document(bookingId).delete()
    }

    func listenToBookings(onChange: @escaping ([Booking]) -> Void) -> ListenerRegistration {
        bookingsCollection
            .order(by: "startTime", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let bookings = documents.compactMap { doc in
                    try? doc.data(as: Booking.self)
                }
                onChange(bookings)
            }
    }

    func listenToBookings(forClientId clientId: String, onChange: @escaping ([Booking]) -> Void) -> ListenerRegistration {
        bookingsCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "startTime", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let bookings = documents.compactMap { doc in
                    try? doc.data(as: Booking.self)
                }
                onChange(bookings)
            }
    }
}
