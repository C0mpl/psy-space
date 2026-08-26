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

    private var pendingBookingsCollection: CollectionReference {
        db.collection("pendingBookings")
    }

    // MARK: - Users

    func saveUser(_ user: User, setTherapistRole: Bool = false) async throws {
        // Don't overwrite isTherapist unless explicitly requested
        // This allows admin to set isTherapist: true in Firestore without it being overwritten
        var data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "createdAt": user.createdAt,
            "paymentCredit": user.paymentCredit
        ]

        // Only set isTherapist for new users or when explicitly requested
        if setTherapistRole {
            data["isTherapist"] = user.isTherapist
        }

        try await usersCollection.document(user.id).setData(data, merge: true)
        #if DEBUG
        print("✅ User saved to Firestore: \(user.email ?? "no email")")
        #endif
    }

    /// Creates a new user with isTherapist flag (used for first-time sign-in)
    func createUser(_ user: User) async throws {
        let data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "isTherapist": user.isTherapist,
            "createdAt": user.createdAt,
            "paymentCredit": user.paymentCredit
        ]
        // Use set without merge to create new document
        try await usersCollection.document(user.id).setData(data)
        #if DEBUG
        print("✅ New user created in Firestore: \(user.email ?? "no email")")
        #endif
    }

    func addUserCredit(userId: String, amount: Int) async throws {
        // Use setData with merge to create document if it doesn't exist
        try await usersCollection.document(userId).setData([
            "paymentCredit": FieldValue.increment(Int64(amount))
        ], merge: true)
        #if DEBUG
        print("✅ Added \(amount) credit to user \(userId)")
        #endif
    }

    func useUserCredit(userId: String, amount: Int) async throws {
        // Use setData with merge to create document if it doesn't exist
        try await usersCollection.document(userId).setData([
            "paymentCredit": FieldValue.increment(Int64(-amount))
        ], merge: true)
        #if DEBUG
        print("✅ Used \(amount) credit from user \(userId)")
        #endif
    }

    func fetchUser(userId: String) async throws -> User? {
        let doc = try await usersCollection.document(userId).getDocument()
        guard let data = doc.data() else { return nil }

        return User(
            id: userId,
            email: data["email"] as? String,
            name: data["name"] as? String ?? "",
            isTherapist: data["isTherapist"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            paymentCredit: data["paymentCredit"] as? Int ?? 0
        )
    }

    func listenToUser(userId: String, onChange: @escaping (User?) -> Void) -> ListenerRegistration {
        usersCollection.document(userId).addSnapshotListener { snapshot, error in
            #if DEBUG
            if let error {
                print("❌ FirestoreService: User listener error: \(error)")
                return
            }
            #endif

            guard let data = snapshot?.data() else {
                onChange(nil)
                return
            }

            let user = User(
                id: userId,
                email: data["email"] as? String,
                name: data["name"] as? String ?? "",
                isTherapist: data["isTherapist"] as? Bool ?? false,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
                paymentCredit: data["paymentCredit"] as? Int ?? 0
            )

            #if DEBUG
            print("🔥 FirestoreService: User updated (credit: \(user.paymentCredit))")
            #endif

            onChange(user)
        }
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
        #if DEBUG
        print("🔥 FirestoreService: Updating booking \(booking.bookingId)")
        if let request = booking.rescheduleRequest {
            print("   - Has reschedule request: \(request.status)")
        } else {
            print("   - No reschedule request (will be cleared)")
        }
        #endif
        // Use setData WITHOUT merge to ensure nil fields are properly removed
        try bookingsCollection.document(booking.bookingId).setData(from: booking)
        #if DEBUG
        print("✅ FirestoreService: Booking updated")
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
                    print("❌ FirestoreService: Listener error: \(error)")
                    return
                }
                print("🔥 FirestoreService: Received snapshot with \(snapshot?.documents.count ?? 0) documents")
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
                        print("❌ FirestoreService: Failed to decode booking \(doc.documentID): \(error)")
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
                    print("❌ FirestoreService: Client listener error: \(error)")
                    return
                }
                print("🔥 FirestoreService: Client received snapshot with \(snapshot?.documents.count ?? 0) documents")
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
                        print("❌ FirestoreService: Client failed to decode booking \(doc.documentID): \(error)")
                        #endif
                        return nil
                    }
                }
                onChange(bookings)
            }
    }

    // MARK: - Pending Bookings (for payment flow)

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
