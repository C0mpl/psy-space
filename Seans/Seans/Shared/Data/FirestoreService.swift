//
//  FirestoreService.swift
//  Seans
//
//  Created by Ilias Mirzoiev on 24.08.2026.
//

import FirebaseFirestore
import Foundation

final class FirestoreService: @unchecked Sendable {
    static let shared = FirestoreService()

    private var db: Firestore { Firestore.firestore() }

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

    private var therapistConfigDocument: DocumentReference {
        db.collection("config").document("therapist")
    }

    func saveTherapistAuthCode(_ authCode: String) async throws {
        try await therapistConfigDocument.setData([
            "calendarAuthCode": authCode,
            "calendarAuthCodeSavedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func saveUser(_ user: User, setTherapistRole: Bool = false) async throws {
        var data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "createdAt": user.createdAt,
            "paymentCredit": user.paymentCredit,
            "calendarSyncEnabled": user.calendarSyncEnabled
        ]

        if setTherapistRole {
            data["isTherapist"] = user.isTherapist
        }

        try await usersCollection.document(user.id).setData(data, merge: true)
        #if DEBUG
        print("✅ User saved to Firestore: \(user.email ?? "no email")")
        #endif
    }

    func createUser(_ user: User) async throws {
        let data: [String: Any] = [
            "email": user.email ?? "",
            "name": user.name,
            "isTherapist": user.isTherapist,
            "createdAt": user.createdAt,
            "paymentCredit": user.paymentCredit,
            "calendarSyncEnabled": user.calendarSyncEnabled
        ]
        try await usersCollection.document(user.id).setData(data)
        #if DEBUG
        print("✅ New user created in Firestore: \(user.email ?? "no email")")
        #endif
    }

    func addUserCredit(userId: String, amount: Int) async throws {
        try await usersCollection.document(userId).setData([
            "paymentCredit": FieldValue.increment(Int64(amount))
        ], merge: true)
        #if DEBUG
        print("✅ Added \(amount) credit to user \(userId)")
        #endif
    }

    func useUserCredit(userId: String, amount: Int) async throws {
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
            paymentCredit: data["paymentCredit"] as? Int ?? 0,
            calendarSyncEnabled: data["calendarSyncEnabled"] as? Bool ?? false
        )
    }

    func fetchTherapist() async throws -> User? {
        let snapshot = try await usersCollection
            .whereField("isTherapist", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            return nil
        }

        let data = doc.data()

        return User(
            id: doc.documentID,
            email: data["email"] as? String,
            name: data["name"] as? String ?? "",
            isTherapist: true,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            paymentCredit: data["paymentCredit"] as? Int ?? 0,
            calendarSyncEnabled: data["calendarSyncEnabled"] as? Bool ?? false
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
                paymentCredit: data["paymentCredit"] as? Int ?? 0,
                calendarSyncEnabled: data["calendarSyncEnabled"] as? Bool ?? false
            )

            #if DEBUG
            print("🔥 FirestoreService: User updated (credit: \(user.paymentCredit))")
            #endif

            onChange(user)
        }
    }

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

    // MARK: - Journal

    private var journalEntriesCollection: CollectionReference {
        db.collection("journalEntries")
    }

    func createJournalEntry(_ entry: JournalEntry) async throws {
        try journalEntriesCollection.document(entry.entryId).setData(from: entry)
        #if DEBUG
        print("✅ Journal entry created: \(entry.entryId)")
        #endif
    }

    func updateJournalEntry(_ entry: JournalEntry) async throws {
        try journalEntriesCollection.document(entry.entryId).setData(from: entry)
        #if DEBUG
        print("✅ Journal entry updated: \(entry.entryId)")
        #endif
    }

    func deleteJournalEntry(_ entryId: String) async throws {
        try await journalEntriesCollection.document(entryId).delete()
        #if DEBUG
        print("✅ Journal entry deleted: \(entryId)")
        #endif
    }

    func fetchJournalEntries(forClientId clientId: String) async throws -> [JournalEntry] {
        let snapshot = try await journalEntriesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: JournalEntry.self)
        }
    }

    func listenToJournalEntries(
        forClientId clientId: String,
        onChange: @escaping ([JournalEntry]) -> Void
    ) -> ListenerRegistration {
        journalEntriesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreService: Journal listener error: \(error)")
                    return
                }
                print("🔥 FirestoreService: Journal received \(snapshot?.documents.count ?? 0) entries")
                #endif
                guard let documents = snapshot?.documents else { return }
                let entries = documents.compactMap { doc in
                    try? doc.data(as: JournalEntry.self)
                }
                onChange(entries)
            }
    }

    func listenToSharedJournalEntries(
        forClientId clientId: String,
        onChange: @escaping ([JournalEntry]) -> Void
    ) -> ListenerRegistration {
        // Query all entries for client, filter and sort client-side
        // This avoids requiring any Firestore indexes
        #if DEBUG
        print("🔍 FirestoreService: Setting up shared entries listener for clientId: '\(clientId)'")
        #endif
        return journalEntriesCollection
            .whereField("clientId", isEqualTo: clientId)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("❌ FirestoreService: Shared journal listener error: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                }
                #endif
                guard let documents = snapshot?.documents else {
                    #if DEBUG
                    print("🔥 FirestoreService: No documents found for clientId: '\(clientId)'")
                    #endif
                    onChange([])
                    return
                }
                #if DEBUG
                print("🔥 FirestoreService: Found \(documents.count) total documents for clientId: '\(clientId)'")
                #endif
                let entries = documents.compactMap { doc in
                    try? doc.data(as: JournalEntry.self)
                }
                .filter { $0.isShared }
                .sorted { $0.createdAt > $1.createdAt }
                #if DEBUG
                print("🔥 FirestoreService: After filtering isShared=true: \(entries.count) entries")
                #endif
                onChange(entries)
            }
    }

    // MARK: - Session Notes

    private var sessionNotesCollection: CollectionReference {
        db.collection("sessionNotes")
    }

    func createSessionNote(_ note: SessionNote) async throws {
        try sessionNotesCollection.document(note.noteId).setData(from: note)
        #if DEBUG
        print("Session note created: \(note.noteId)")
        #endif
    }

    func updateSessionNote(_ note: SessionNote) async throws {
        try sessionNotesCollection.document(note.noteId).setData(from: note)
        #if DEBUG
        print("Session note updated: \(note.noteId)")
        #endif
    }

    func deleteSessionNote(_ noteId: String) async throws {
        try await sessionNotesCollection.document(noteId).delete()
        #if DEBUG
        print("Session note deleted: \(noteId)")
        #endif
    }

    func fetchSessionNotes(forClientId clientId: String) async throws -> [SessionNote] {
        let snapshot = try await sessionNotesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: SessionNote.self)
        }
    }

    func listenToSessionNotes(
        forClientId clientId: String,
        onChange: @escaping ([SessionNote]) -> Void
    ) -> ListenerRegistration {
        sessionNotesCollection
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                #if DEBUG
                if let error {
                    print("FirestoreService: Session notes listener error: \(error)")
                    return
                }
                print("FirestoreService: Session notes received \(snapshot?.documents.count ?? 0) notes")
                #endif
                guard let documents = snapshot?.documents else { return }
                let notes = documents.compactMap { doc in
                    try? doc.data(as: SessionNote.self)
                }
                onChange(notes)
            }
    }

    // MARK: - Client Anamnesis

    private var anamnesisCollection: CollectionReference {
        db.collection("clientAnamnesis")
    }

    func saveAnamnesis(_ anamnesis: ClientAnamnesis) async throws {
        try anamnesisCollection.document(anamnesis.clientId).setData(from: anamnesis)
        #if DEBUG
        print("Anamnesis saved for client: \(anamnesis.clientId)")
        #endif
    }

    func fetchAnamnesis(forClientId clientId: String) async throws -> ClientAnamnesis? {
        let doc = try await anamnesisCollection.document(clientId).getDocument()
        return try? doc.data(as: ClientAnamnesis.self)
    }

    func listenToAnamnesis(
        forClientId clientId: String,
        onChange: @escaping (ClientAnamnesis?) -> Void
    ) -> ListenerRegistration {
        anamnesisCollection.document(clientId).addSnapshotListener { snapshot, error in
            #if DEBUG
            if let error {
                print("FirestoreService: Anamnesis listener error: \(error)")
                return
            }
            #endif
            guard let snapshot, snapshot.exists else {
                onChange(nil)
                return
            }
            let anamnesis = try? snapshot.data(as: ClientAnamnesis.self)
            #if DEBUG
            print("FirestoreService: Anamnesis received for client: \(clientId)")
            #endif
            onChange(anamnesis)
        }
    }
}
